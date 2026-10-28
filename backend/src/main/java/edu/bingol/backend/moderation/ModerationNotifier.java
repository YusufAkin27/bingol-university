package edu.bingol.backend.moderation;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.util.Map;
import org.springframework.stereotype.Component;

/** Moderasyon bildirimleri; hepsi alicinin kayitli dilinde (tr/en/ar). Hata fırlatmaz (NotificationService yutar). */
@Component
public class ModerationNotifier {

    private final NotificationService notifications;
    private final I18n i18n;
    private final UserRepository users;

    public ModerationNotifier(NotificationService notifications, I18n i18n, UserRepository users) {
        this.notifications = notifications;
        this.i18n = i18n;
        this.users = users;
    }

    /** Yonetilebilir sebep sablonlari (P11); yoksa sabit DecisionReason metinleri. */
    private edu.bingol.backend.moderation.admin.ReasonTemplateService templates;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setTemplates(edu.bingol.backend.moderation.admin.ReasonTemplateService templates) {
        this.templates = templates;
    }

    /** Karar nedeni sablonunun alici dilindeki metni; yoksa null. */
    public String reasonText(Long userId, String reasonCode) {
        if (templates != null) {
            return templates.text(reasonCode, i18n.langOf(userId));
        }
        return DecisionReason.parse(reasonCode)
                .map(r -> i18n.msg(r.messageKey(), i18n.langOf(userId)))
                .orElse(null);
    }

    /** Esik asildi: icerik gecici gizlendi, itiraz edilebilir. */
    public void autoHidden(Long ownerId, ReportTargetType type, Long targetId) {
        notifications.sendTemplated(ownerId, NotificationType.SYSTEM, "notif.mod.autohidden", data(type, targetId));
    }

    /** Yonetici karari: icerik kaldirildi. detail = yonetici mesaji veya neden sablonu metni. */
    public void removed(Long ownerId, ReportTargetType type, Long targetId, String detail) {
        notifications.sendTemplated(ownerId, NotificationType.SYSTEM, "notif.mod.removed", data(type, targetId),
                detail == null ? "-" : detail);
    }

    /** Yonetici karari: uyari. Mevcut WARN metinleri korunur; detay verilirse govdeye yazilir. */
    public void warned(Long ownerId, String detail) {
        notifications.sendLocalized(ownerId, NotificationType.SYSTEM, "notif.report.warn.title",
                detail == null || detail.isBlank() ? "notif.report.warn.body" : null, detail, null);
    }

    /** Icerik yeniden gorunur (rapor reddedildi veya itiraz kabul). */
    public void restored(Long ownerId, ReportTargetType type, Long targetId) {
        notifications.sendTemplated(ownerId, NotificationType.SYSTEM, "notif.mod.restored", data(type, targetId));
    }

    /** Yonetici ihlali affetti (P11): ihlal sayilmaz. */
    public void strikeForgiven(Long userId) {
        notifications.sendTemplated(userId, NotificationType.SYSTEM, "notif.mod.strike.forgiven", null);
    }

    /** Raporlayana sonuc bilgisi. */
    public void reporterOutcome(Long reporterId, boolean actioned) {
        notifications.sendTemplated(reporterId, NotificationType.SYSTEM,
                actioned ? "notif.mod.reporter.actioned" : "notif.mod.reporter.dismissed", null);
    }

    public void reporterRestricted(Long reporterId, int days) {
        notifications.sendTemplated(reporterId, NotificationType.SYSTEM, "notif.mod.reporter.restricted", null,
                String.valueOf(days));
    }

    public void appealDecided(Long userId, boolean accepted, String note) {
        notifications.sendTemplated(userId, NotificationType.SYSTEM,
                accepted ? "notif.mod.appeal.accepted" : "notif.mod.appeal.rejected", null,
                note == null || note.isBlank() ? "-" : note);
    }

    /** Yoneticilere: yeni itiraz. */
    public void adminAppealOpened(Long appealId) {
        toAdmins("notif.mod.admin.appeal", Map.of("appealId", String.valueOf(appealId)), String.valueOf(appealId));
    }

    /** Yoneticilere: tekrarlayan ihlal, askiya alma onerisi. */
    public void adminRecommendation(Long userId, int strikes) {
        toAdmins("notif.mod.admin.recommend", Map.of("userId", String.valueOf(userId)), String.valueOf(userId),
                String.valueOf(strikes));
    }

    private void toAdmins(String key, Map<String, String> data, String... args) {
        for (UserRepository.UserLang a : users.audienceAdmins()) {
            notifications.sendTemplated(a.getId(), NotificationType.SYSTEM, key, data, args);
        }
    }

    private static Map<String, String> data(ReportTargetType type, Long targetId) {
        return Map.of("targetType", type.name(), "targetId", String.valueOf(targetId));
    }

    /** Test/diger modullerin kullanabilmesi icin dil çözümü. */
    public Lang langOf(Long userId) {
        return i18n.langOf(userId);
    }
}
