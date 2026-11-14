package edu.bingol.backend.academician;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.notification.FanoutNotifier;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

/**
 * Akademisyen alani bildirimleri: onay/ret/iptal (uygulama ici + e-posta, alicinin dilinde), yonetici bilgilendirmesi ve
 * kayitli ogrencilere ders bildirimleri. Teslimat projenin mevcut hattindan gider (NotificationService.sendTemplatedBulk:
 * tercih/sessize alma/sessiz saat/PushGate tek karar tablosu; FanoutNotifier: commit sonrasi sinirli havuz). Servis
 * sozlesmesi: hata cagirana sizmaz.
 */
@Component
public class AcademicianNotifier {

    private static final Logger log = LoggerFactory.getLogger(AcademicianNotifier.class);
    private static final DateTimeFormatter WHEN = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final int CHUNK = 250;

    private final NotificationService notifications;
    private final MailService mail;
    private final I18n i18n;
    private final UserRepository users;
    private final AcEnrollmentRepository enrollments;
    private FanoutNotifier fanout;

    public AcademicianNotifier(NotificationService notifications, MailService mail, I18n i18n, UserRepository users,
                               AcEnrollmentRepository enrollments) {
        this.notifications = notifications;
        this.mail = mail;
        this.i18n = i18n;
        this.users = users;
        this.enrollments = enrollments;
    }

    @Autowired(required = false)
    void setFanout(FanoutNotifier fanout) {
        this.fanout = fanout;
    }

    // ---- yonetici karari: basvurana uygulama ici + e-posta ----

    public enum Decision {
        APPROVED("approved"), REJECTED("rejected"), REVOKED("revoked");

        private final String key;

        Decision(String key) {
            this.key = key;
        }
    }

    public void decided(Long userId, Decision d, String reason) {
        String base = "notif.academician." + d.key;
        try {
            if (d == Decision.APPROVED) {
                notifications.sendTemplated(userId, NotificationType.SYSTEM, base, Map.of("type", "ACADEMICIAN_STATUS", "status", "APPROVED"));
            } else {
                notifications.sendTemplated(userId, NotificationType.SYSTEM, base,
                        Map.of("type", "ACADEMICIAN_STATUS", "status", d.name()), reason == null ? "" : reason);
            }
        } catch (RuntimeException e) {
            log.warn("Akademisyen karar bildirimi gonderilemedi userId={}: {}", userId, e.toString());
        }
        try {
            User u = users.findById(userId).orElse(null);
            if (u != null && u.getEmail() != null) {
                Lang lang = Lang.of(u.getLanguage());
                String heading = i18n.msg("mail.academician." + d.key + ".heading", lang);
                String body = i18n.msg("mail.academician." + d.key + ".body", lang, reason == null ? "" : reason);
                mail.sendAnnouncement(u.getEmail(), heading, body, lang);
            }
        } catch (RuntimeException e) {
            log.warn("Akademisyen karar e-postasi kuyruga yazilamadi userId={}: {}", userId, e.toString());
        }
    }

    /** Otomatik onay olunca her yoneticiye bilgi (ad/unvan; e-posta yok). */
    public void autoApproved(String academicianName) {
        try {
            for (UserRepository.UserLang admin : users.audienceAdmins()) {
                notifications.sendTemplated(admin.getId(), NotificationType.SYSTEM, "notif.academician.autoApproved",
                        Map.of("type", "ACADEMICIAN_ADMIN", "route", "/admin/academicians"), academicianName);
            }
        } catch (RuntimeException e) {
            log.warn("Otomatik onay yonetici bildirimi gonderilemedi: {}", e.toString());
        }
    }

    // ---- ogrenci bildirimleri ----

    /** Ogrencilere derse eklendi bildirimi (toplu, commit sonrasi). */
    public void enrolled(Long courseId, String courseName, String academicianName, Collection<Long> studentIds) {
        if (studentIds.isEmpty()) {
            return;
        }
        List<Long> ids = List.copyOf(studentIds);
        Map<String, String> data = courseData(courseId, "ENROLLED");
        FanoutNotifier.dispatch(fanout, "academician-enrolled:" + courseId, () -> {
            for (int i = 0; i < ids.size(); i += CHUNK) {
                notifications.sendTemplatedBulk(ids.subList(i, Math.min(ids.size(), i + CHUNK)), TEMPLATE_ENROLLED, data, null,
                        courseName, academicianName);
            }
        });
    }

    /** Dersin tum kayitli ogrencilerine sabit tur bildirimi (commit sonrasi, 250'lik parcalarla). */
    public void courseNotice(AcCourse course, AcNotice.Type type, String title, Instant eventAt, String note) {
        Long courseId = course.getId();
        String courseName = course.getName();
        NotificationTemplates.Template t = templateOf(type);
        Map<String, String> data = courseData(courseId, type.name());
        String shownTitle = title == null ? "" : title;
        String shownNote = note == null ? "" : note;
        String when = eventAt == null ? "" : WHEN.format(eventAt.atZone(ZONE));
        FanoutNotifier.dispatch(fanout, "academician-notice:" + courseId, () -> {
            long after = 0;
            while (true) {
                List<Long> ids = enrollments.studentIdsAfter(courseId, after, PageRequest.of(0, CHUNK));
                if (ids.isEmpty()) {
                    break;
                }
                notifications.sendTemplatedBulk(ids, t, data, null, courseName, shownTitle, when, shownNote);
                after = ids.get(ids.size() - 1);
                if (ids.size() < CHUNK) {
                    break;
                }
            }
        });
    }

    /** Otomatik devamsizlik uyarisi: duzey 1 risk, duzey 2 sinira ulasildi. Hata cagirana sizmaz. */
    public void absence(AcCourse course, Long studentId, int level, int absent) {
        try {
            NotificationTemplates.Template t = NotificationTemplates.of(
                    level >= 2 ? "notif.academician.absenceExceeded" : "notif.academician.absenceWarning", NotificationType.SYSTEM);
            notifications.sendTemplate(studentId, t, courseData(course.getId(), level >= 2 ? "ABSENCE_EXCEEDED" : "ABSENCE_WARNING"),
                    null, course.getName(),
                    String.valueOf(absent), AbsenceWarningService.limitText(course));
        } catch (RuntimeException e) {
            log.warn("Devamsizlik uyarisi gonderilemedi studentId={}: {}", studentId, e.toString());
        }
    }

    /**
     * Ogrenciye giden ders bildirimlerinin hedefi: uygulamanin mevcut sozlesmesi (PostNotifier/ForumNotifier gibi)
     * {@code target}/{@code value} ve push yukunde {@code targetType}/{@code targetId}; ikisi de ACADEMIC_COURSE + dersin kimligi.
     * Ek anahtarlar (courseId, noticeType) zararsizdir.
     */
    static Map<String, String> courseData(Long courseId, String noticeType) {
        Map<String, String> d = new java.util.LinkedHashMap<>();
        d.put("type", "ACADEMICIAN_COURSE");
        d.put("target", "ACADEMIC_COURSE");
        d.put("value", courseId.toString());
        d.put("targetType", "ACADEMIC_COURSE");
        d.put("targetId", courseId.toString());
        d.put("courseId", courseId.toString());
        d.put("noticeType", noticeType);
        return d;
    }

    // ---- sablonlar (anahtarlar messages*.properties'te; kayit NotificationTemplates statik blogunda) ----

    static final NotificationTemplates.Template TEMPLATE_ENROLLED = NotificationTemplates.of("notif.academician.enrolled",
            NotificationType.SYSTEM);

    static NotificationTemplates.Template templateOf(AcNotice.Type type) {
        return NotificationTemplates.of(switch (type) {
            case LESSON_STARTED -> "notif.academician.lessonStarted";
            case ATTENDANCE_STARTED -> "notif.academician.attendanceStarted";
            case EXAM -> "notif.academician.exam";
            case ASSIGNMENT -> "notif.academician.assignment";
            case MATERIAL -> "notif.academician.material";
            case LESSON_CANCELLED -> "notif.academician.lessonCancelled";
            case ROOM_CHANGED -> "notif.academician.roomChanged";
        }, NotificationType.ANNOUNCEMENT);
    }
}
