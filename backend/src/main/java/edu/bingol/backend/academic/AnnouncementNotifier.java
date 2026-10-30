package edu.bingol.backend.academic;

import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * notify=true duyurular gorunur oldugunda (hemen ya da publishAt gelince) hedef kitleye BIR KEZ bildirim yollar.
 * Cok ornekte tekrar gonderim olmasin diye "notified_at IS NULL" kosullu UPDATE ile sahiplenilir. Hata akisi bozmaz.
 */
@Component
public class AnnouncementNotifier {

    private static final Logger log = LoggerFactory.getLogger(AnnouncementNotifier.class);

    private final JdbcTemplate jdbc;
    private final NotificationService notifications;
    private final Clock clock;

    @Autowired
    public AnnouncementNotifier(JdbcTemplate jdbc, NotificationService notifications) {
        this(jdbc, notifications, Clock.systemUTC());
    }

    AnnouncementNotifier(JdbcTemplate jdbc, NotificationService notifications, Clock clock) {
        this.jdbc = jdbc;
        this.notifications = notifications;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${app.academic.notify-poll-ms:60000}", initialDelayString = "${app.academic.notify-poll-ms:60000}")
    public void dispatchDue() {
        try {
            Timestamp now = Timestamp.from(clock.instant());
            List<Long> ids = jdbc.queryForList("SELECT id FROM department_announcement WHERE notify = TRUE AND notified_at IS NULL "
                    + "AND published = TRUE AND publish_at <= ? AND (expires_at IS NULL OR expires_at > ?) ORDER BY id LIMIT 20",
                    Long.class, now, now);
            ids.forEach(this::dispatch);
        } catch (RuntimeException e) {
            log.warn("Duyuru bildirimi taramasi basarisiz: {}", e.toString());
        }
    }

    /** Gorunur ve notify ise gonderir; degilse hicbir sey yapmaz. */
    public void dispatchIfDue(long id) {
        try {
            Timestamp now = Timestamp.from(clock.instant());
            Long n = jdbc.queryForObject("SELECT COUNT(*) FROM department_announcement WHERE id = ? AND notify = TRUE "
                    + "AND notified_at IS NULL AND published = TRUE AND publish_at <= ? AND (expires_at IS NULL OR expires_at > ?)",
                    Long.class, id, now, now);
            if (n != null && n > 0) {
                dispatch(id);
            }
        } catch (RuntimeException e) {
            log.warn("Duyuru bildirimi basarisiz (id={}): {}", id, e.toString());
        }
    }

    private void dispatch(long id) {
        Instant now = clock.instant();
        // Sahiplenme: yalnizca ilk guncelleyen gonderir
        int claimed = jdbc.update("UPDATE department_announcement SET notified_at = ? WHERE id = ? AND notified_at IS NULL",
                Timestamp.from(now), id);
        if (claimed == 0) {
            return;
        }
        try {
            jdbc.query("SELECT title, body, department, faculty, grade FROM department_announcement WHERE id = ?", rs -> {
                List<Long> users = DepartmentAnnouncementService.audienceIds(jdbc, rs.getString("department"), rs.getString("faculty"),
                        rs.getString("grade"));
                String body = rs.getString("body");
                Map<String, String> data = new LinkedHashMap<>();
                data.put("target", "ANNOUNCEMENT");
                data.put("value", String.valueOf(id));
                data.put("announcementId", String.valueOf(id));
                int sent = notifications.sendBulk(users, NotificationType.ANNOUNCEMENT, rs.getString("title"),
                        body.length() > 140 ? body.substring(0, 140) + "…" : body, data, "academic_announcements");
                log.info("Duyuru {} bildirimi: hedef={} kayit={}", id, users.size(), sent);
            }, id);
        } catch (RuntimeException e) {
            log.warn("Duyuru {} bildirimi gonderilemedi: {}", id, e.toString());
        }
    }
}
