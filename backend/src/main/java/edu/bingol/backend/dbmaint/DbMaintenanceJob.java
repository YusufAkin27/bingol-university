package edu.bingol.backend.dbmaint;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gece 03:00 (Europe/Istanbul) saklama/temizlik gorevleri. Her gorev parcali (ChunkedDeleter) ve birbirinden
 * bagimsizdir: biri patlarsa digerleri calisir. Cok ornekte SchedulerLock ile tek ornek. Eski isler (analitik 03:15,
 * bildirim 03:30, mail 03:40, push 03:20) kalan kucuk farki siler; buradakiler agir yuku once ve parcali alir.
 *
 * <p>Kapsam: bildirim (okunmus/okunmamis yas + kullanici basina ust sinir), mail kuyrugu (SENT kisa, DEAD uzun),
 * admin denetim kaydi, mesaj erisim/kulup denetimi, analitik toplulastirma + ham olay saklama.
 */
@Component
public class DbMaintenanceJob {

    private static final Logger log = LoggerFactory.getLogger(DbMaintenanceJob.class);

    private final ChunkedDeleter deleter;
    private final NamedParameterJdbcTemplate jdbc;
    private final AnalyticsRollup rollup;
    private final SchedulerLock lock;
    private final Clock clock;
    private final boolean enabled;
    private final int notifReadDays;
    private final int notifUnreadDays;
    private final int notifCap;
    private final int mailSentDays;
    private final int mailDeadDays;
    private final int adminAuditDays;
    private final int auditLongDays;
    private final int analyticsRawDays;
    private final int activityDays;
    private final int crashDays;

    public DbMaintenanceJob(ChunkedDeleter deleter, NamedParameterJdbcTemplate jdbc, AnalyticsRollup rollup,
                            SchedulerLock lock, Clock clock,
                            @Value("${app.dbmaint.enabled:true}") boolean enabled,
                            @Value("${app.notification.retention-days:30}") int notifReadDays,
                            @Value("${app.notification.unread-retention-days:90}") int notifUnreadDays,
                            @Value("${app.dbmaint.notification-per-user-cap:200}") int notifCap,
                            @Value("${app.dbmaint.mail-sent-days:7}") int mailSentDays,
                            @Value("${app.dbmaint.mail-dead-days:30}") int mailDeadDays,
                            @Value("${app.dbmaint.admin-audit-days:365}") int adminAuditDays,
                            @Value("${app.dbmaint.audit-long-days:730}") int auditLongDays,
                            @Value("${app.dbmaint.analytics-raw-days:45}") int analyticsRawDays,
                            @Value("${app.dbmaint.activity-daily-days:400}") int activityDays,
                            @Value("${app.dbmaint.crash-days:30}") int crashDays) {
        this.deleter = deleter;
        this.jdbc = jdbc;
        this.rollup = rollup;
        this.lock = lock;
        this.clock = clock;
        this.enabled = enabled;
        this.notifReadDays = notifReadDays;
        this.notifUnreadDays = notifUnreadDays;
        this.notifCap = notifCap;
        this.mailSentDays = mailSentDays;
        this.mailDeadDays = mailDeadDays;
        this.adminAuditDays = adminAuditDays;
        this.auditLongDays = auditLongDays;
        this.analyticsRawDays = analyticsRawDays;
        this.activityDays = activityDays;
        this.crashDays = crashDays;
    }

    @Scheduled(cron = "${app.dbmaint.cron:0 0 3 * * *}", zone = "Europe/Istanbul")
    public void nightly() {
        if (!enabled) {
            return;
        }
        lock.tryRun("dbmaint-nightly", Duration.ofMinutes(60), this::runAll);
    }

    /** Tum gorevleri sirayla calistirir; gorev adi -> silinen satir. Hata cagirana sizmaz. */
    public Map<String, Integer> runAll() {
        Instant now = clock.instant();
        Map<String, Integer> out = new LinkedHashMap<>();
        // once toplulastir, sonra ham olayi sil (toplulastirilmamis gun silinmesin)
        out.put("analytics_rollup_days", safe("analytics_rollup", rollup::rollUpMissingDays));
        out.put("analytics_event", safe("analytics_event", () -> rawEvents(now)));
        out.put("activity_daily", safe("activity_daily", () -> activityDaily()));
        out.put("notification_read", safe("notification_read", () -> notifRead(now)));
        out.put("notification_unread", safe("notification_unread", () -> notifUnread(now)));
        out.put("notification_cap", safe("notification_cap", this::notifCap));
        out.put("mail_sent", safe("mail_sent", () -> mailSent(now)));
        out.put("mail_dead", safe("mail_dead", () -> mailDead(now)));
        out.put("admin_audit", safe("admin_audit", () -> adminAudit(now)));
        out.put("message_access_audit", safe("message_access_audit", () -> longAudit("message_access_audit", now)));
        out.put("club_audit", safe("club_audit", () -> longAudit("club_audit", now)));
        out.put("crash_event", safe("crash_event", () -> crashEvents(now)));
        out.put("crash_group", safe("crash_group", () -> crashGroups(now)));
        log.info("dbmaint tamam: {}", out);
        return out;
    }

    private int safe(String name, Supplier<Integer> task) {
        try {
            return task.get();
        } catch (RuntimeException e) {
            log.warn("dbmaint gorevi basarisiz ({}): {}", name, e.toString());
            return 0;
        }
    }

    private static OffsetDateTime cutoff(Instant now, int days) {
        return now.minus(Duration.ofDays(days)).atOffset(ZoneOffset.UTC);
    }

    private int rawEvents(Instant now) {
        return analyticsRawDays <= 0 ? 0 : deleter.delete("analytics_event",
                "DELETE FROM analytics_event WHERE id IN (SELECT id FROM analytics_event WHERE created_at < :cutoff ORDER BY id LIMIT :lim)",
                Map.of("cutoff", cutoff(now, analyticsRawDays)));
    }

    /** Gunluk acilis sayaci: raporlar en cok 366 gun sorgular; 400 gunden eskisi gereksiz. */
    private int activityDaily() {
        return activityDays <= 0 ? 0 : deleter.delete("activity_daily",
                "DELETE FROM activity_daily WHERE (user_id, day) IN (SELECT user_id, day FROM activity_daily WHERE day < :cutoff LIMIT :lim)",
                Map.of("cutoff", java.time.LocalDate.now(clock.withZone(java.time.ZoneId.of("Europe/Istanbul"))).minusDays(activityDays)));
    }

    private int notifRead(Instant now) {
        return notifReadDays <= 0 ? 0 : deleter.delete("notification_read",
                "DELETE FROM notification WHERE id IN (SELECT id FROM notification WHERE read_at IS NOT NULL AND read_at < :cutoff LIMIT :lim)",
                Map.of("cutoff", cutoff(now, notifReadDays)));
    }

    private int notifUnread(Instant now) {
        return notifUnreadDays <= 0 ? 0 : deleter.delete("notification_unread",
                "DELETE FROM notification WHERE id IN (SELECT id FROM notification WHERE read_at IS NULL AND created_at < :cutoff LIMIT :lim)",
                Map.of("cutoff", cutoff(now, notifUnreadDays)));
    }

    /** Kullanici basina en yeni N bildirim kalir. Yalniz siniri asan kullanicilar taranir (idx_notification_user). */
    private int notifCap() {
        if (notifCap <= 0) {
            return 0;
        }
        List<Long> users = jdbc.getJdbcTemplate().queryForList(
                "SELECT user_id FROM notification GROUP BY user_id HAVING count(*) > ? LIMIT 5000", Long.class, notifCap);
        int total = 0;
        for (Long uid : users) {
            total += deleter.delete("notification_cap",
                    "DELETE FROM notification WHERE id IN (SELECT id FROM notification WHERE user_id = :uid AND id < "
                            + "(SELECT id FROM notification WHERE user_id = :uid ORDER BY id DESC LIMIT 1 OFFSET :cap) LIMIT :lim)",
                    Map.of("uid", uid, "cap", notifCap - 1));
        }
        return total;
    }

    private int mailSent(Instant now) {
        return mailSentDays <= 0 ? 0 : deleter.delete("mail_sent",
                "DELETE FROM mail_outbox WHERE id IN (SELECT id FROM mail_outbox WHERE status = 'SENT' AND sent_at < :cutoff LIMIT :lim)",
                Map.of("cutoff", cutoff(now, mailSentDays)));
    }

    private int mailDead(Instant now) {
        return mailDeadDays <= 0 ? 0 : deleter.delete("mail_dead",
                "DELETE FROM mail_outbox WHERE id IN (SELECT id FROM mail_outbox WHERE status = 'DEAD' AND created_at < :cutoff LIMIT :lim)",
                Map.of("cutoff", cutoff(now, mailDeadDays)));
    }

    private int adminAudit(Instant now) {
        return adminAuditDays <= 0 ? 0 : deleter.delete("admin_audit",
                "DELETE FROM admin_audit WHERE id IN (SELECT id FROM admin_audit WHERE created_at < :cutoff ORDER BY id LIMIT :lim)",
                Map.of("cutoff", cutoff(now, adminAuditDays)));
    }

    /** CR1: cokme olaylari 30 gun (anonim; grup basina son 50 siniri alim aninda uygulanir). */
    private int crashEvents(Instant now) {
        return crashDays <= 0 ? 0 : deleter.delete("crash_event",
                "DELETE FROM crash_event WHERE id IN (SELECT id FROM crash_event WHERE received_at < :cutoff ORDER BY id LIMIT :lim)",
                Map.of("cutoff", cutoff(now, crashDays)));
    }

    /** CR1: son gorulmesi saklama suresini asan gruplar (olay/surum satirlari CASCADE ile gider). */
    private int crashGroups(Instant now) {
        return crashDays <= 0 ? 0 : deleter.delete("crash_group",
                "DELETE FROM crash_group WHERE id IN (SELECT id FROM crash_group WHERE last_seen_at < :cutoff ORDER BY id LIMIT :lim)",
                Map.of("cutoff", cutoff(now, crashDays)));
    }

    /** Tablo adi sabit beyaz listeden gelir (kullanici girdisi degil). */
    private int longAudit(String table, Instant now) {
        if (auditLongDays <= 0 || !(table.equals("message_access_audit") || table.equals("club_audit"))) {
            return 0;
        }
        return deleter.delete(table,
                "DELETE FROM " + table + " WHERE id IN (SELECT id FROM " + table + " WHERE created_at < :cutoff ORDER BY id LIMIT :lim)",
                Map.of("cutoff", cutoff(now, auditLongDays)));
    }
}
