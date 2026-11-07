package edu.bingol.backend.crash;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.crash.CrashDtos.ReportRequest;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Anonim cokme raporu alimi: sunucuda ikinci kez maskeler, imzaya gore {@code crash_group}'a toplar, olay ekler
 * (grup basina son {@code app.crash.max-events-per-group} olay), surum dagilimini gunceller, cozulmus grup yeni
 * surumde tekrarlarsa yeniden acar. Yeni/yeniden acilan grup yoneticiye ozet bildirim icin sayaca yazilir
 * ({@link CrashAlertService}); istek yolunda bildirim gonderilmez. PostgreSQL'e ozel SQL (ON CONFLICT, RETURNING,
 * xmax): H2 testlerinde degil, duman betigiyle (scripts/smoke-crash-reports.sh) dogrulanir.
 *
 * <p>FIX-P09 (A08#1, A09#1) firtina korumasi: (1) {@code SELECT ... FOR UPDATE} yok; grup tek
 * {@code INSERT .. ON CONFLICT DO UPDATE .. RETURNING} ile alinir/guncellenir, yeniden acma kosullu UPDATE'tir;
 * (2) ayni imza dakikada {@code app.crash.group-per-minute} kez DB'ye yazilir, fazlasi Redis'te sayilip dakikada bir
 * toplu eklenir ({@link CrashThrottle}); (3) DB yazimi en cok {@code app.crash.max-concurrent-writes} (4) es zamanli,
 * kisa bekleme sonunda sessizce dusurulur (istemci raporu zaten yeniden denemez); (4) islem 2 sn ile sinirlidir;
 * (5) Redis cagrilari islem disindadir; (6) en eski olay budamasi her {@code N}. olayda calisir.
 */
@Service
public class CrashService {

    private static final Logger log = LoggerFactory.getLogger(CrashService.class);
    /** Islem zaman asimi (sn): firtinada havuz baglantisi uzun tutulmaz. */
    static final int TX_TIMEOUT_SECONDS = 2;
    /** Es zamanli yazma kapisini bekleme suresi (ms). */
    static final long GATE_WAIT_MS = 250;
    /** Tasma sayaci toplu isleme turu basina en cok bu kadar alan. */
    static final int FLUSH_MAX_FIELDS = 500;

    private final NamedParameterJdbcTemplate jdbc;
    private final StringRedisTemplate redis;
    private final Clock clock;
    private final int maxEvents;
    private final int trimEvery;
    private final TransactionTemplate tx;
    private final CrashThrottle throttle;
    private final SchedulerLock lock;
    private final Semaphore gate;

    public CrashService(NamedParameterJdbcTemplate jdbc, StringRedisTemplate redis, Clock clock,
                        PlatformTransactionManager txManager, CrashThrottle throttle, SchedulerLock lock,
                        @Value("${app.crash.max-events-per-group:50}") int maxEvents,
                        @Value("${app.crash.max-concurrent-writes:4}") int maxConcurrentWrites) {
        this.jdbc = jdbc;
        this.redis = redis;
        this.clock = clock;
        this.maxEvents = Math.max(5, Math.min(maxEvents, 500));
        this.trimEvery = Math.max(1, Math.min(10, this.maxEvents / 5));
        this.tx = new TransactionTemplate(txManager);
        this.tx.setTimeout(TX_TIMEOUT_SECONDS);
        this.throttle = throttle;
        this.lock = lock;
        this.gate = new Semaphore(Math.max(1, maxConcurrentWrites));
    }

    /** Sonuc: grup kimligi ve (yeni acildi | yeniden acildi) bilgisi. groupId -1: DB'ye yazilmadi (frenlendi/dusuruldu). */
    public record Outcome(long groupId, boolean created, boolean reopened) {
        static final Outcome SKIPPED = new Outcome(-1, false, false);
    }

    /** {@code INSERT .. ON CONFLICT .. RETURNING} sonucu (guncelleme oncesi durum alanlari degismez). */
    record GroupState(long id, String status, String lastVersion, String fixedIn, String resolvedAt, long eventCount,
                      boolean created) {
    }

    public Outcome record(ReportRequest r) {
        Instant now = clock.instant();
        String errorType = CrashScrubber.text(r.errorType(), 160);
        if (errorType == null) {
            errorType = "Unknown";
        }
        String stack = CrashScrubber.stack(r.stackTrace());
        String message = CrashScrubber.text(r.message(), 300);
        String platform = platform(r.platform());
        String version = r.appVersion().strip();
        String signature = CrashScrubber.signature(errorType, stack);
        Instant occurred = occurredAt(r.occurredAt(), now);

        if (!throttle.allow(signature, now)) {
            throttle.countOverflow(signature, version, platform);
            return Outcome.SKIPPED;
        }
        boolean acquired = false;
        try {
            acquired = gate.tryAcquire(GATE_WAIT_MS, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        if (!acquired) {
            log.debug("Cokme raporu dusuruldu: yazma kapisi dolu");
            return Outcome.SKIPPED;
        }
        Outcome out;
        try {
            final String type = errorType;
            out = tx.execute(status -> persist(now, type, message, stack, platform, version, signature, occurred, r));
        } finally {
            gate.release();
        }
        if (out != null && (out.created() || out.reopened())) {
            markPending(); // Redis, islem disinda
        }
        return out == null ? Outcome.SKIPPED : out;
    }

    private Outcome persist(Instant now, String errorType, String message, String stack, String platform,
                            String version, String signature, Instant occurred, ReportRequest r) {
        MapSqlParameterSource gp = new MapSqlParameterSource()
                .addValue("sig", signature).addValue("type", errorType).addValue("msg", message)
                .addValue("top", CrashScrubber.topFrame(stack)).addValue("v", version)
                .addValue("now", Timestamp.from(now));
        // FOR UPDATE yok: satir kilidi yalniz bu ifade ile islem sonu arasindadir (3 kisa ifade) ve dakikada
        // imza basina en cok group-per-minute islem buraya gelir.
        GroupState g = jdbc.queryForObject("INSERT INTO crash_group (signature, error_type, message_sample, top_frame, "
                + "first_seen_at, last_seen_at, first_version, last_version, event_count) "
                + "VALUES (:sig, :type, :msg, :top, :now, :now, :v, :v, 1) "
                + "ON CONFLICT (signature) DO UPDATE SET event_count = crash_group.event_count + 1, "
                + "last_seen_at = :now, message_sample = COALESCE(crash_group.message_sample, EXCLUDED.message_sample) "
                + "RETURNING id, status, last_version, fixed_in_version, resolved_at_version, event_count, "
                + "(xmax = 0) AS created", gp,
                (rs, i) -> new GroupState(rs.getLong("id"), rs.getString("status"), rs.getString("last_version"),
                        rs.getString("fixed_in_version"), rs.getString("resolved_at_version"),
                        rs.getLong("event_count"), rs.getBoolean("created")));
        long groupId = g.id();
        boolean reopened = !g.created() && "RESOLVED".equals(g.status())
                && shouldReopen(version, g.fixedIn(), g.resolvedAt());
        if (reopened) {
            // kosullu UPDATE: es zamanli yonetici islemi ya da baska rapor ayni gecisi yaptiysa 0 satir
            reopened = jdbc.update("UPDATE crash_group SET status = 'NEW', reopen_count = reopen_count + 1, "
                    + "status_by = 'system', status_at = :now, status_reason = NULL, fixed_in_version = NULL, "
                    + "resolved_at_version = NULL WHERE id = :id AND status = 'RESOLVED'",
                    new MapSqlParameterSource().addValue("id", groupId).addValue("now", Timestamp.from(now))) == 1;
        }
        String lastVersion = g.lastVersion();
        if (!g.created() && (lastVersion == null || CrashScrubber.compareVersions(version, lastVersion) >= 0)
                && !version.equals(lastVersion)) {
            jdbc.update("UPDATE crash_group SET last_version = :v WHERE id = :id",
                    new MapSqlParameterSource().addValue("id", groupId).addValue("v", version));
        }

        jdbc.update("INSERT INTO crash_event (group_id, app_version, platform, os_version, device_model, screen, "
                        + "fatal, message, stack, occurred_at, received_at) "
                        + "VALUES (:g, :v, :p, :os, :model, :screen, :fatal, :msg, :stack, :occ, :now)",
                new MapSqlParameterSource().addValue("g", groupId).addValue("v", version).addValue("p", platform)
                        .addValue("os", CrashScrubber.text(r.osVersion(), 64))
                        .addValue("model", CrashScrubber.text(r.deviceModel(), 64))
                        .addValue("screen", CrashScrubber.text(r.screen(), 80))
                        .addValue("fatal", Boolean.TRUE.equals(r.fatal())).addValue("msg", message)
                        .addValue("stack", stack).addValue("occ", Timestamp.from(occurred))
                        .addValue("now", Timestamp.from(now)));
        jdbc.update("INSERT INTO crash_group_version (group_id, app_version, platform, cnt, last_seen_at) "
                        + "VALUES (:g, :v, :p, 1, :now) ON CONFLICT (group_id, app_version, platform) "
                        + "DO UPDATE SET cnt = crash_group_version.cnt + 1, last_seen_at = EXCLUDED.last_seen_at",
                new MapSqlParameterSource().addValue("g", groupId).addValue("v", version).addValue("p", platform)
                        .addValue("now", Timestamp.from(now)));
        if (g.eventCount() % trimEvery == 0) {
            trim(groupId);
        }
        return new Outcome(groupId, g.created(), reopened);
    }

    /** Grup basina yalniz son N olay kalir (id ARTAN: en yeni = en buyuk). */
    private void trim(long groupId) {
        jdbc.update("DELETE FROM crash_event WHERE group_id = :g AND id < "
                        + "(SELECT id FROM crash_event WHERE group_id = :g ORDER BY id DESC LIMIT 1 OFFSET :off)",
                Map.of("g", groupId, "off", maxEvents - 1));
    }

    // ---- tasma sayaclarinin toplu islenmesi ----

    @Scheduled(fixedDelay = 60_000, initialDelay = 90_000)
    public void scheduledFlush() {
        lock.tryRun("crash-overflow", Duration.ofSeconds(55), this::flushOverflow);
    }

    /**
     * Esik ustu olaylarin sayaclarini {@code event_count} ve surum dagilimina ekler. Servis sozlesmesi: istisna
     * sizdirmaz; bir alan islenemezse sayac Redis'e geri konur. @return eklenen toplam olay.
     */
    long flushOverflow() {
        long total = 0;
        try {
            Instant now = clock.instant();
            for (Map.Entry<String, Long> e : throttle.takeOverflow(FLUSH_MAX_FIELDS).entrySet()) {
                String[] f = CrashThrottle.parse(e.getKey());
                if (f == null) {
                    continue;
                }
                try {
                    tx.executeWithoutResult(s -> applyOverflow(f[0], f[1], f[2], e.getValue(), now));
                    total += e.getValue();
                } catch (RuntimeException ex) {
                    throttle.restore(e.getKey(), e.getValue());
                    log.warn("Cokme tasma sayaci islenemedi: {}", ex.toString());
                }
            }
        } catch (RuntimeException ex) {
            log.warn("Cokme tasma toplu islemi basarisiz: {}", ex.toString());
        }
        return total;
    }

    private void applyOverflow(String signature, String version, String platform, long n, Instant now) {
        List<Long> ids = jdbc.queryForList("SELECT id FROM crash_group WHERE signature = :sig",
                Map.of("sig", signature), Long.class);
        if (ids.isEmpty()) {
            return; // grup saklama suresi nedeniyle silinmis
        }
        long id = ids.get(0);
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("id", id).addValue("n", n)
                .addValue("v", version).addValue("p", platform).addValue("now", Timestamp.from(now));
        jdbc.update("UPDATE crash_group SET event_count = event_count + :n, last_seen_at = :now WHERE id = :id", p);
        jdbc.update("INSERT INTO crash_group_version (group_id, app_version, platform, cnt, last_seen_at) "
                + "VALUES (:id, :v, :p, :n, :now) ON CONFLICT (group_id, app_version, platform) "
                + "DO UPDATE SET cnt = crash_group_version.cnt + EXCLUDED.cnt, "
                + "last_seen_at = EXCLUDED.last_seen_at", p);
        trim(id);
    }

    /** Yoneticiye ozet bildirimi icin bekleyen yeni-grup sayaci (Redis yoksa sessizce atlanir). */
    private void markPending() {
        try {
            redis.opsForValue().increment(CrashAlertService.PENDING_KEY);
            redis.expire(CrashAlertService.PENDING_KEY, Duration.ofDays(2));
        } catch (RuntimeException e) {
            log.debug("Cokme bildirim sayaci yazilamadi: {}", e.toString());
        }
    }

    /**
     * Yeniden acma kurali: yonetici duzeltme surumu bildirdiyse o surum ve sonrasi; bildirmediyse cozuldugu andaki
     * son surumden YENI bir surum (eski surumdeki gec gelen raporlar grubu yeniden acmaz).
     */
    static boolean shouldReopen(String version, String fixedIn, String resolvedAt) {
        if (fixedIn != null && !fixedIn.isBlank()) {
            return CrashScrubber.compareVersions(version, fixedIn) >= 0;
        }
        return resolvedAt != null && CrashScrubber.compareVersions(version, resolvedAt) > 0;
    }

    static String platform(String p) {
        String s = p == null ? "" : p.strip().toUpperCase(Locale.ROOT);
        return switch (s) {
            case "ANDROID", "IOS" -> s;
            default -> "OTHER";
        };
    }

    /** Istemci saati: yoksa, gelecekte (>5 dk) ya da 30 gunden eskiyse alim zamani. */
    static Instant occurredAt(Instant client, Instant now) {
        if (client == null || client.isAfter(now.plus(Duration.ofMinutes(5)))
                || client.isBefore(now.minus(Duration.ofDays(30)))) {
            return now;
        }
        return client;
    }
}
