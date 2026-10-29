package edu.bingol.backend.observability;

import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.PushDispatcher;
import java.io.File;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.stereotype.Service;

/**
 * Tum sistem gostergelerini tek yanitta toplar ({@code GET /api/admin/system/overview}). Her olcum kendi icinde
 * hata yakalar: bir gosterge cokse bile digerleri doner (cokenin kendisi CRIT/UNKNOWN olur).
 */
@Service
public class SystemOverviewService {

    /** Sik/gecelik/aylik gorev turu: esik carpanlari farklidir. */
    enum JobKind { POLLER, NIGHTLY, MONTHLY, SLOW }

    record JobSpec(String key, String job, JobKind kind) {
    }

    /** Izlenen zamanlayicilar (bkz. CLAUDE.md zamanlayici tablosu). Bu paket baska paketlerin kodunu degistirmez. */
    static final List<JobSpec> JOBS = List.of(
            new JobSpec("news-sync", "NewsSyncService.scheduledSync", JobKind.NIGHTLY),
            new JobSpec("menu-sync", "MenuSyncService.scheduledSync", JobKind.MONTHLY),
            new JobSpec("mail-queue", "MailQueueWorker.poll", JobKind.POLLER),
            new JobSpec("push-queue", "PushOutboxWorker.poll", JobKind.POLLER),
            new JobSpec("campaign-dispatch", "CampaignService.dispatchDue", JobKind.POLLER),
            new JobSpec("mail-campaign", "MailCampaignDispatcher.poll", JobKind.POLLER),
            new JobSpec("mail-purge", "MailQueueWorker.purgeOld", JobKind.NIGHTLY),
            new JobSpec("push-purge", "PushOutboxWorker.purgeOld", JobKind.NIGHTLY),
            new JobSpec("device-cleanup", "DeviceCleanupJob.scheduled", JobKind.NIGHTLY),
            new JobSpec("notification-retention", "NotificationRetentionJob.scheduled", JobKind.NIGHTLY),
            new JobSpec("analytics-retention", "EventRetention.purge", JobKind.NIGHTLY),
            new JobSpec("storage-alert", "StorageAlertJob.scheduled", JobKind.SLOW));

    /** Tum gosterge anahtarlari (metrik kaydi icin sabit liste). */
    public static List<String> indicatorKeys() {
        java.util.ArrayList<String> keys = new java.util.ArrayList<>(List.of(
                "mail.dead", "mail.pending", "mail.oldestPendingAge", "mail.dailyQuota",
                "push.dead", "push.pending", "push.oldestPendingAge",
                "campaign.overdue", "campaign.counts",
                "websocket.sessions", "db", "redis", "fcm", "disk.storage", "storage", "backup.age"));
        for (JobSpec j : JOBS) {
            keys.add("jobs." + j.key());
        }
        return keys;
    }

    /** Yanit: olusma zamani, genel durum ve gosterge haritasi. */
    public record Overview(Instant generatedAt, IndicatorStatus overall, Map<String, Indicator> indicators) {
        public List<String> critKeys() {
            return indicators.entrySet().stream().filter(e -> e.getValue().status() == IndicatorStatus.CRIT)
                    .map(Map.Entry::getKey).toList();
        }
    }

    private record Cached(long at, Overview overview) {
    }

    private static final long CACHE_MS = 15_000;

    private final ObservabilityProperties props;
    private final QueueQueries queues;
    private final JdbcTemplate jdbc;
    private final StringRedisTemplate redis;
    private final ObjectProvider<SimpUserRegistry> users;
    private final ObjectProvider<PushDispatcher> push;
    private final JobMonitor jobs;
    private final BackupStatusProvider backup;
    private final StorageProperties storage;
    private final I18n i18n;
    private final ObjectProvider<edu.bingol.backend.mail.MailDailyQuota> mailQuota;
    private final StorageUsageService storageUsage;
    private final AtomicReference<Cached> cache = new AtomicReference<>();

    public SystemOverviewService(ObservabilityProperties props, QueueQueries queues, JdbcTemplate jdbc,
                                 StringRedisTemplate redis, ObjectProvider<SimpUserRegistry> users,
                                 ObjectProvider<PushDispatcher> push, JobMonitor jobs, BackupStatusProvider backup,
                                 StorageProperties storage, I18n i18n,
                                 ObjectProvider<edu.bingol.backend.mail.MailDailyQuota> mailQuota,
                                 StorageUsageService storageUsage) {
        this.mailQuota = mailQuota;
        this.storageUsage = storageUsage;
        this.props = props;
        this.queues = queues;
        this.jdbc = jdbc;
        this.redis = redis;
        this.users = users;
        this.push = push;
        this.jobs = jobs;
        this.backup = backup;
        this.storage = storage;
        this.i18n = i18n;
    }

    /** Metrik/uyari icin kisa omurlu onbellek (Turkce mesajlarla). */
    public Overview cached() {
        long now = System.currentTimeMillis();
        Cached c = cache.get();
        if (c == null || now - c.at() > CACHE_MS) {
            c = new Cached(now, evaluate(Lang.DEFAULT.locale()));
            cache.set(c);
        }
        return c.overview();
    }

    public Overview evaluate(Locale locale) {
        Instant now = Instant.now();
        Map<String, Indicator> out = new LinkedHashMap<>();
        safe(out, "mail", () -> mail(out, now, locale));
        safe(out, "push", () -> push(out, now, locale));
        safe(out, "campaign", () -> campaigns(out, now, locale));
        safe(out, "websocket", () -> out.put("websocket.sessions", websocket()));
        out.put("db", db(locale));
        out.put("redis", redis(locale));
        out.put("fcm", fcm(locale));
        out.put("disk.storage", disk(locale));
        out.put("storage", storage(locale));
        out.put("backup.age", backup(now, locale));
        for (JobSpec j : JOBS) {
            out.put("jobs." + j.key(), job(j, now, locale));
        }
        return new Overview(now, overall(out.values()), out);
    }

    /** Genel durum: UNKNOWN'lar gormezden gelinir; hicbir bilinen gosterge yoksa UNKNOWN. */
    static IndicatorStatus overall(Iterable<Indicator> all) {
        IndicatorStatus s = IndicatorStatus.UNKNOWN;
        for (Indicator i : all) {
            s = IndicatorStatus.worse(s, i.status());
        }
        return s;
    }

    private void safe(Map<String, Indicator> out, String group, Runnable r) {
        try {
            r.run();
        } catch (RuntimeException e) {
            out.put(group + ".error", new Indicator(IndicatorStatus.CRIT, null, null,
                    msg(Lang.DEFAULT.locale(), "obs.msg.QUERY_FAILED", group)));
        }
    }

    // ---- kuyruklar ----

    private void mail(Map<String, Indicator> out, Instant now, Locale l) {
        QueueQueries.QueueStats q = queues.mail(now);
        out.put("mail.dead", dead(q.count("DEAD"), l));
        out.put("mail.pending", Indicator.ok(q.pending(), null));
        out.put("mail.oldestPendingAge", age(q.oldestOverdueSeconds(), l));
        out.put("mail.dailyQuota", dailyQuota(l));
    }

    /** Gunluk e-posta kotasi kullanimi (%): %80 WARN, %95 CRIT; kota korumasi kapaliysa UNKNOWN. */
    private Indicator dailyQuota(Locale l) {
        edu.bingol.backend.mail.MailDailyQuota q = mailQuota.getIfAvailable();
        if (q == null || !q.enabled()) {
            return Indicator.unknown(null);
        }
        long pct = Math.round(q.percent());
        IndicatorStatus st = Indicator.byThreshold(pct, 80, 95);
        return new Indicator(st, pct, Map.of("warn", 80, "crit", 95),
                st == IndicatorStatus.OK ? null : msg(l, "obs.msg.MAIL_QUOTA", pct));
    }

    private void push(Map<String, Indicator> out, Instant now, Locale l) {
        QueueQueries.QueueStats q = queues.push(now);
        out.put("push.dead", dead(q.count("DEAD"), l));
        out.put("push.pending", Indicator.ok(q.pending(), null));
        out.put("push.oldestPendingAge", age(q.oldestOverdueSeconds(), l));
    }

    private void campaigns(Map<String, Indicator> out, Instant now, Locale l) {
        QueueQueries.QueueStats q = queues.campaigns(now);
        out.put("campaign.counts", Indicator.ok(q.byStatus(), null));
        out.put("campaign.overdue", age(q.oldestOverdueSeconds(), l, "obs.msg.CAMPAIGN_OVERDUE"));
    }

    Indicator dead(long count, Locale l) {
        IndicatorStatus st = Indicator.byThreshold(count, props.deadWarn(), props.deadCrit() + 1.0);
        // "> N = CRIT": esik N'in ustu; ByThreshold >= kullandigi icin crit+1 verilir.
        Map<String, Object> th = Map.of("warn", props.deadWarn(), "crit", props.deadCrit());
        return new Indicator(st, count, th, st == IndicatorStatus.OK ? null : msg(l, "obs.msg.DEAD", count));
    }

    private Indicator age(Long seconds, Locale l) {
        return age(seconds, l, "obs.msg.QUEUE_AGE");
    }

    /** Eskilik: > WARN dk WARN, > CRIT dk CRIT. Deger saniye; bekleyen yoksa 0. */
    private Indicator age(Long seconds, Locale l, String key) {
        long s = seconds == null ? 0 : seconds;
        long warn = props.queueAgeWarnMinutes() * 60L;
        long crit = props.queueAgeCritMinutes() * 60L;
        IndicatorStatus st = Indicator.byThreshold(s, 0, 0);
        if (s > crit) {
            st = IndicatorStatus.CRIT;
        } else if (s > warn) {
            st = IndicatorStatus.WARN;
        }
        Map<String, Object> th = Map.of("warn", warn, "crit", crit);
        return new Indicator(st, s, th, st == IndicatorStatus.OK ? null : msg(l, key, s / 60));
    }

    // ---- altyapi ----

    private Indicator websocket() {
        SimpUserRegistry r = users.getIfAvailable();
        if (r == null) {
            return Indicator.unknown(null);
        }
        long sessions = 0;
        for (SimpUser u : r.getUsers()) {
            sessions += u.getSessions().size();
        }
        return Indicator.ok(sessions, null);
    }

    private Indicator db(Locale l) {
        long t0 = System.nanoTime();
        try {
            jdbc.queryForObject("SELECT 1", Integer.class);
        } catch (RuntimeException e) {
            return new Indicator(IndicatorStatus.CRIT, null, null, msg(l, "obs.msg.DB_DOWN"));
        }
        long ms = (System.nanoTime() - t0) / 1_000_000;
        IndicatorStatus st = ms >= props.dbWarnMillis() ? IndicatorStatus.WARN : IndicatorStatus.OK;
        return new Indicator(st, ms, Map.of("warn", props.dbWarnMillis()),
                st == IndicatorStatus.OK ? null : msg(l, "obs.msg.DB_SLOW", ms));
    }

    private Indicator redis(Locale l) {
        long t0 = System.nanoTime();
        try {
            redis.execute((RedisCallback<String>) c -> c.ping());
        } catch (RuntimeException e) {
            return new Indicator(IndicatorStatus.CRIT, null, null, msg(l, "obs.msg.REDIS_DOWN"));
        }
        return Indicator.ok((System.nanoTime() - t0) / 1_000_000, null);
    }

    /** FCM kapaliysa UNKNOWN (kimlik girilmemis olabilir; uyari uretmez); acikken son hata yakin ise WARN. */
    private Indicator fcm(Locale l) {
        PushDispatcher p = push.getIfAvailable();
        if (p == null || !p.fcmEnabled()) {
            return Indicator.unknown(msg(l, "obs.msg.FCM_OFF"));
        }
        Instant lastFail = p.lastFailureAt();
        Map<String, Object> value = new LinkedHashMap<>();
        value.put("delivered", p.deliveredCount());
        value.put("failures", p.failureCount());
        value.put("lastFailureAt", lastFail == null ? null : lastFail.toString());
        boolean recent = lastFail != null && Duration.between(lastFail, Instant.now()).toMinutes() < 15;
        return new Indicator(recent ? IndicatorStatus.WARN : IndicatorStatus.OK, value, null,
                recent ? msg(l, "obs.msg.FCM_FAILING") : null);
    }

    private Indicator disk(Locale l) {
        try {
            File dir = new File(storage.dir() == null || storage.dir().isBlank() ? "." : storage.dir())
                    .getAbsoluteFile();
            while (dir != null && !dir.exists()) {
                dir = dir.getParentFile();
            }
            if (dir == null || dir.getTotalSpace() <= 0) {
                return Indicator.unknown(msg(l, "obs.msg.DISK_UNKNOWN"));
            }
            double used = (dir.getTotalSpace() - dir.getUsableSpace()) * 100.0 / dir.getTotalSpace();
            double pct = Math.round(used * 10) / 10.0;
            IndicatorStatus st = Indicator.byThreshold(pct, props.diskWarnPercent(), props.diskCritPercent());
            return new Indicator(st, pct, Map.of("warn", props.diskWarnPercent(), "crit", props.diskCritPercent()),
                    st == IndicatorStatus.OK ? null : msg(l, "obs.msg.DISK_HIGH", String.valueOf(pct)));
        } catch (RuntimeException e) {
            return Indicator.unknown(msg(l, "obs.msg.DISK_UNKNOWN"));
        }
    }

    /** Depolama doluluk (veri saklama sayfasi): en yuksek disk yuzdesi; WARN/CRIT esikleri storage-*-percent. */
    private Indicator storage(Locale l) {
        try {
            StorageUsageService.Report r = storageUsage.report();
            Map<String, Object> th = Map.of("warn", props.storageWarnPercent(), "crit", props.storageCritPercent());
            if (r.worstPercent() == null) {
                return new Indicator(IndicatorStatus.UNKNOWN, null, th, msg(l, "obs.msg.STORAGE_UNKNOWN"));
            }
            return new Indicator(r.status(), r.worstPercent(), th, r.status() == IndicatorStatus.OK ? null
                    : msg(l, "obs.msg.STORAGE_HIGH", String.valueOf(r.worstPercent()), String.valueOf(r.worstKey())));
        } catch (RuntimeException e) {
            return Indicator.unknown(msg(l, "obs.msg.STORAGE_UNKNOWN"));
        }
    }

    private Indicator backup(Instant now, Locale l) {
        Optional<Instant> last = backup.lastSuccess();
        Map<String, Object> th = Map.of("warn", props.backupWarnHours(), "crit", props.backupCritHours());
        if (last.isEmpty()) {
            return new Indicator(IndicatorStatus.UNKNOWN, null, th, msg(l, "obs.msg.BACKUP_UNKNOWN"));
        }
        double hours = Math.max(0, Duration.between(last.get(), now).toSeconds()) / 3600.0;
        double rounded = Math.round(hours * 10) / 10.0;
        IndicatorStatus st = backupStatus(hours, props);
        return new Indicator(st, rounded, th,
                st == IndicatorStatus.OK ? null : msg(l, "obs.msg.BACKUP_OLD", String.valueOf(rounded)));
    }

    /** Saatlik yedek: > warn saat WARN, > crit saat CRIT. */
    static IndicatorStatus backupStatus(double ageHours, ObservabilityProperties p) {
        if (ageHours > p.backupCritHours()) {
            return IndicatorStatus.CRIT;
        }
        return ageHours > p.backupWarnHours() ? IndicatorStatus.WARN : IndicatorStatus.OK;
    }

    // ---- zamanlayicilar ----

    private Indicator job(JobSpec spec, Instant now, Locale l) {
        long max = switch (spec.kind()) {
            case POLLER -> props.pollerMaxAgeSeconds();
            case NIGHTLY -> props.nightlyMaxAgeHours() * 3600L;
            case MONTHLY -> props.monthlyMaxAgeDays() * 86400L;
            case SLOW -> 45 * 60L; // 15 dk'lik donem x3
        };
        Optional<JobMonitor.Stat> stat = jobs.stat(spec.job());
        Map<String, Object> th = Map.of("warn", max, "crit", max * critFactor(spec.kind()));
        if (stat.isEmpty()) {
            return new Indicator(IndicatorStatus.UNKNOWN, null, th, msg(l, "obs.msg.JOB_NEVER"));
        }
        IndicatorStatus st = jobStatus(stat.get(), now, max, critFactor(spec.kind()));
        Long age = stat.get().lastSuccess() == null ? null
                : Math.max(0, Duration.between(stat.get().lastSuccess(), now).toSeconds());
        String message = switch (st) {
            case OK, UNKNOWN -> null;
            default -> stat.get().lastSuccess() == null || (age != null && age > max)
                    ? msg(l, "obs.msg.JOB_STALE", age == null ? "-" : String.valueOf(age / 60))
                    : msg(l, "obs.msg.JOB_ERROR");
        };
        return new Indicator(st, age, th, message);
    }

    static int critFactor(JobKind kind) {
        return kind == JobKind.POLLER ? 3 : 2;
    }

    /** Son basari yasi > max WARN, > max*carpan CRIT; son hata son basariyi gectiyse en az WARN. */
    static IndicatorStatus jobStatus(JobMonitor.Stat s, Instant now, long maxSeconds, int critFactor) {
        IndicatorStatus st = IndicatorStatus.OK;
        if (s.lastSuccess() == null) {
            return IndicatorStatus.WARN; // calisti ama hic basarili olmadi
        }
        long age = Math.max(0, Duration.between(s.lastSuccess(), now).toSeconds());
        if (age > maxSeconds * critFactor) {
            st = IndicatorStatus.CRIT;
        } else if (age > maxSeconds) {
            st = IndicatorStatus.WARN;
        }
        if (s.lastError() != null && s.lastError().isAfter(s.lastSuccess())) {
            st = IndicatorStatus.worse(st, IndicatorStatus.WARN);
        }
        return st;
    }

    private String msg(Locale l, String key, Object... args) {
        Object[] a = new Object[args.length];
        for (int i = 0; i < args.length; i++) {
            a[i] = String.valueOf(args[i]); // sayilar yerel bicimlenmesin; kesme isareti kullanilmaz
        }
        return i18n.msg(key, l, a);
    }
}
