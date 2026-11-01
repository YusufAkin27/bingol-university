package edu.bingol.backend.academic;

import edu.bingol.backend.common.AfterCommit;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * notify=true duyurular gorunur oldugunda (hemen ya da publishAt gelince) hedef kitleye BIR KEZ bildirim yollar.
 * Cok ornekte tekrar gonderim olmasin diye "notified_at IS NULL" kosullu UPDATE ile sahiplenilir. Hata akisi bozmaz.
 *
 * <p>FIX-P08 (A07#4/#11/#12): yonetici istegi artik toplu bildirimi BEKLEMEZ. {@link #dispatchIfDue} yazan islem COMMIT
 * olduktan sonra (geri alinmis duyuru bildirmesin) tek iscilik, sinirli kuyruklu bir yurutucuya devredilir; kuyruk
 * doluysa gonderim dakikalik zamanlayiciya ({@link #dispatchDue}) kalir. Duyuru satiri ONCE okunur, gonderim
 * sonuc-kumesi geri cagrisinin disinda yapilir (uzun gonderim boyunca bir baglanti tutulmaz). Hedef kitle cozumlenemezse
 * sahiplenme geri alinir (hicbir sey gonderilmedi, zamanlayici yeniden dener).
 *
 * <p>FINAL-ALL: fan-out noktasi {@link #send} {@code sendTemplatedBulk} kullanir (alt tur tercihi, sessiz saat, PushGate).
 */
@Component
public class AnnouncementNotifier {

    private static final Logger log = LoggerFactory.getLogger(AnnouncementNotifier.class);

    /** Basligi/govdesi yoneticinin yazdigi duyuru metnidir (cevrilmez): `{0}` baslik, `{1}` govde. */
    static final NotificationTemplates.Template TEMPLATE = NotificationTemplates.register("notif.academic.announcement",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.ACADEMIC_ANNOUNCEMENT);

    private final JdbcTemplate jdbc;
    private final NotificationService notifications;
    private final Clock clock;
    /** null = ayni is parcaciginda calisir (birim testleri); uretimde tek iscilik sinirli yurutucu. */
    private final Executor async;

    @Autowired
    public AnnouncementNotifier(JdbcTemplate jdbc, NotificationService notifications) {
        this(jdbc, notifications, Clock.systemUTC(), newExecutor());
    }

    AnnouncementNotifier(JdbcTemplate jdbc, NotificationService notifications, Clock clock) {
        this(jdbc, notifications, clock, null);
    }

    AnnouncementNotifier(JdbcTemplate jdbc, NotificationService notifications, Clock clock, Executor async) {
        this.jdbc = jdbc;
        this.notifications = notifications;
        this.clock = clock;
        this.async = async;
    }

    private static Executor newExecutor() {
        ThreadPoolExecutor ex = new ThreadPoolExecutor(1, 1, 30, TimeUnit.SECONDS, new ArrayBlockingQueue<>(64),
                r -> {
                    Thread t = new Thread(r, "announcement-notify");
                    t.setDaemon(true);
                    return t;
                }, new ThreadPoolExecutor.DiscardPolicy()); // dolarsa zamanlayici (notified_at IS NULL) yakalar
        ex.allowCoreThreadTimeOut(true);
        return ex;
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

    /**
     * Gorunur ve notify ise gonderir; degilse hicbir sey yapmaz. Cagiran islem varsa COMMIT'ten sonra, istek
     * is parcacigindan bagimsiz calisir.
     */
    public void dispatchIfDue(long id) {
        AfterCommit.run(() -> {
            if (async == null) {
                dispatchIfDueNow(id);
            } else {
                async.execute(() -> dispatchIfDueNow(id));
            }
        });
    }

    void dispatchIfDueNow(long id) {
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

    private record Row(String title, String body, String department, String faculty, String grade) {}

    private void dispatch(long id) {
        Instant now = clock.instant();
        // Sahiplenme: yalnizca ilk guncelleyen gonderir
        int claimed = jdbc.update("UPDATE department_announcement SET notified_at = ? WHERE id = ? AND notified_at IS NULL",
                Timestamp.from(now), id);
        if (claimed == 0) {
            return;
        }
        List<Long> users;
        Row row;
        try {
            // Satir ONCE okunur: sonuc-kumesi geri cagrisi icinde uzun gonderim yapilmaz (baglanti tutulmaz)
            List<Row> rows = jdbc.query("SELECT title, body, department, faculty, grade FROM department_announcement WHERE id = ?",
                    (rs, i) -> new Row(rs.getString("title"), rs.getString("body"), rs.getString("department"),
                            rs.getString("faculty"), rs.getString("grade")), id);
            if (rows.isEmpty()) {
                return; // bu arada silindi
            }
            row = rows.get(0);
            users = DepartmentAnnouncementService.audienceIds(jdbc, row.department(), row.faculty(), row.grade());
        } catch (RuntimeException e) {
            // Hicbir sey gonderilmedi: sahiplenmeyi geri al, zamanlayici yeniden denesin
            release(id);
            log.warn("Duyuru {} hedef kitlesi cozumlenemedi, yeniden denenecek: {}", id, e.toString());
            return;
        }
        try {
            send(id, row, users);
        } catch (RuntimeException e) {
            log.warn("Duyuru {} bildirimi gonderilemedi: {}", id, e.toString());
        }
    }

    private void send(long id, Row row, List<Long> users) {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("target", "ANNOUNCEMENT");
        data.put("value", String.valueOf(id));
        data.put("announcementId", String.valueOf(id));
        String body = row.body();
        // FINAL-ALL (P08 ertelenen): sendBulk yerine sendTemplatedBulk: alt tur tercihi (academic_announcements AND
        // announcements, onceki prefColumn ile ayni), sessiz saat ve PushGate de uygulanir; metin icerik kaynaklidir.
        int sent = notifications.sendTemplatedBulk(users, TEMPLATE, data, null, row.title(),
                body.length() > 140 ? body.substring(0, 140) + "…" : body);
        log.info("Duyuru {} bildirimi: hedef={} kayit={}", id, users.size(), sent);
    }

    private void release(long id) {
        try {
            jdbc.update("UPDATE department_announcement SET notified_at = NULL WHERE id = ?", id);
        } catch (RuntimeException e) {
            log.warn("Duyuru {} sahiplenmesi geri alinamadi: {}", id, e.toString());
        }
    }
}
