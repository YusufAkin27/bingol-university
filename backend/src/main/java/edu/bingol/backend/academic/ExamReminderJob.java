package edu.bingol.backend.academic;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationTemplates.Template;
import edu.bingol.backend.notification.NotificationType;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Kullanicinin KENDI girdigi sinavlar (tt_exam) icin sinavdan ~2 saat once sunucu push'u (FCM; uygulama kapaliyken de).
 *
 * <p>Pencere: {@code starts_at} in [simdi + MIN_LEAD, simdi + LEAD]. Ust sinir 2 saattir; alt sinir kacirma guvenligidir:
 * gorev/sunucu kapali kaldiysa sinava >= 30 dk varken gec de olsa gonderilir, daha yakinsa (ve gecmis sinavlarda) ASLA.
 *
 * <p>Tekrar onleme: {@code tt_exam.reminded_starts_at} (V1010). Gonderimden once kosullu UPDATE ile "sahiplenilir"
 * (yalniz ilk guncelleyen gonderir; cok ornekte de guvenli). Deger sinavin o anki {@code starts_at}'idir: sinav saati
 * sonradan degisirse iki deger ayrisir ve sinav yeniden hatirlatilabilir. Silinen sinav satirla birlikte gider.
 *
 * <p>Alici tercihleri {@link NotificationService} icinde uygulanir (akademik bayrak, sessiz saat, askidaki hesap);
 * FCM yoksa uygulama ici bildirim yine yazilir. Tek kullanicinin hatasi dongunun gerisini durdurmaz.
 */
@Component
public class ExamReminderJob {

    private static final Logger log = LoggerFactory.getLogger(ExamReminderJob.class);

    /** Hatirlatmanin hedef onceligi: sinavdan bu kadar once. */
    static final Duration LEAD = Duration.ofHours(2);
    /** Kacirma guvenligi: sinava bundan az kaldiysa gonderilmez. */
    static final Duration MIN_LEAD = Duration.ofMinutes(30);
    static final int BATCH = 500;
    /** Bir calismada en cok bu kadar parca (BATCH x MAX_BATCHES sinav); kalani sonraki dakikaya kalir. */
    static final int MAX_BATCHES = 10;

    static final Template TEMPLATE = NotificationTemplates.register("notif.academic.examReminder",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.EXAM_REMINDER);
    static final Template TEMPLATE_ROOM = NotificationTemplates.register("notif.academic.examReminderRoom",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.EXAM_REMINDER);

    private static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");

    private final JdbcTemplate jdbc;
    private final NotificationService notifications;
    private final SchedulerLock lock;
    private final Clock clock;

    @Autowired
    public ExamReminderJob(JdbcTemplate jdbc, NotificationService notifications, SchedulerLock lock) {
        this(jdbc, notifications, lock, Clock.systemUTC());
    }

    ExamReminderJob(JdbcTemplate jdbc, NotificationService notifications, SchedulerLock lock, Clock clock) {
        this.jdbc = jdbc;
        this.notifications = notifications;
        this.lock = lock;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${app.exam-reminder.poll-ms:60000}",
            initialDelayString = "${app.exam-reminder.initial-delay-ms:45000}")
    public void scheduled() {
        try {
            // Kilit yoksa (test) dogrudan; Redis erisilemezse tryRun gorevi atlar, sonraki dakikada denenir.
            if (lock == null) {
                run(clock.instant());
            } else {
                lock.tryRun("exam-reminder", Duration.ofMinutes(2), () -> run(clock.instant()));
            }
        } catch (RuntimeException e) {
            log.warn("Sinav hatirlatma gorevi basarisiz: {}", e.toString());
        }
    }

    /** Servis sozlesmesi: istisna sizdirmaz. @return gonderilen hatirlatma sayisi */
    public int run(Instant now) {
        int sent = 0;
        try {
            Timestamp from = Timestamp.from(now.plus(MIN_LEAD));
            Timestamp to = Timestamp.from(now.plus(LEAD));
            for (int i = 0; i < MAX_BATCHES; i++) {
                List<Row> rows = jdbc.query("SELECT id, user_id, title, room, starts_at FROM tt_exam "
                        + "WHERE starts_at >= ? AND starts_at <= ? "
                        + "AND (reminded_starts_at IS NULL OR reminded_starts_at <> starts_at) "
                        + "ORDER BY starts_at, id LIMIT " + BATCH,
                        (rs, n) -> new Row(rs.getLong("id"), rs.getLong("user_id"), rs.getString("title"),
                                rs.getString("room"), rs.getTimestamp("starts_at")),
                        from, to);
                for (Row r : rows) {
                    if (remind(r)) {
                        sent++;
                    }
                }
                if (rows.size() < BATCH) {
                    break;
                }
            }
        } catch (RuntimeException e) {
            log.warn("Sinav hatirlatma taramasi basarisiz: {}", e.toString());
        }
        if (sent > 0) {
            log.info("Sinav hatirlatmasi gonderildi: {}", sent);
        }
        return sent;
    }

    private boolean remind(Row r) {
        try {
            // Sahiplenme: yalniz ilk guncelleyen gonderir; sinav bu arada duzenlendiyse (starts_at degisti) ya da silindiyse 0 doner.
            int claimed = jdbc.update("UPDATE tt_exam SET reminded_starts_at = starts_at WHERE id = ? AND starts_at = ? "
                    + "AND (reminded_starts_at IS NULL OR reminded_starts_at <> starts_at)", r.id, r.startsAt);
            if (claimed == 0) {
                return false;
            }
            try {
                send(r);
                return true;
            } catch (RuntimeException e) {
                // Gonderilemedi: iz geri alinir, sonraki dakika (pencere acikken) tekrar denenir.
                jdbc.update("UPDATE tt_exam SET reminded_starts_at = NULL WHERE id = ? AND starts_at = ?", r.id, r.startsAt);
                log.warn("Sinav hatirlatmasi gonderilemedi (sinav {}): {}", r.id, e.toString());
                return false;
            }
        } catch (RuntimeException e) {
            log.warn("Sinav hatirlatmasi islenemedi (sinav {}): {}", r.id, e.toString());
            return false;
        }
    }

    private void send(Row r) {
        Instant at = r.startsAt.toInstant();
        String hhmm = ZonedDateTime.ofInstant(at, AcademicTime.ZONE).format(HHMM);
        String id = String.valueOf(r.id);
        String room = r.room == null ? "" : r.room.strip();
        Map<String, String> data = Map.of("target", "EXAM", "value", id, "examId", id);
        // Ayni sinav + ayni saat icin tek bildirim (okunmamis tekrar birlesir); saat degisirse yeni anahtar.
        String collapse = "exam:" + id + ":" + at.getEpochSecond();
        if (room.isEmpty()) {
            notifications.sendTemplate(r.userId, TEMPLATE, data, collapse, r.title, hhmm);
        } else {
            notifications.sendTemplate(r.userId, TEMPLATE_ROOM, data, collapse, r.title, hhmm, room);
        }
    }

    private record Row(long id, long userId, String title, String room, Timestamp startsAt) {}
}
