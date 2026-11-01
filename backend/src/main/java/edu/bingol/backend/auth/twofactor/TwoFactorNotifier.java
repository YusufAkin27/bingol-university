package edu.bingol.backend.auth.twofactor;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import java.time.Clock;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 2FA guvenlik bildirimleri: uygulama ici bildirim + e-posta, ikisi de alicinin kayitli dilinde. Servis sozlesmesi:
 * hicbir hata cagirana sizmaz (bildirim basarisiz diye guvenlik islemi geri alinmaz).
 */
@Component
public class TwoFactorNotifier {

    private static final Logger log = LoggerFactory.getLogger(TwoFactorNotifier.class);
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    /** `key`: bildirim anahtari `notif.twofactor.<key>.title|body`, e-posta metni `mail.twofactor.<key>`. */
    public enum Event {
        /** Kullanici 2FA'yi acti. */
        ENABLED("enabled"),
        /** Kullanici 2FA'yi sifresiyle kapatti. */
        DISABLED_BY_USER("userdisabled"),
        /** Yonetici hesap kurtarma kapatmasi. */
        DISABLED_BY_ADMIN("disabled"),
        /** Ust uste tukenen challenge'lar: yeni cihazdan giris kilitlendi. */
        WRONG_CODES("wrongcodes");

        private final String key;

        Event(String key) {
            this.key = key;
        }

        String key() {
            return key;
        }
    }

    private final NotificationService notifications;
    private final MailService mail;
    private final I18n i18n;
    private final Clock clock;

    public TwoFactorNotifier(NotificationService notifications, MailService mail, I18n i18n, Clock clock) {
        this.notifications = notifications;
        this.mail = mail;
        this.i18n = i18n;
        this.clock = clock;
    }

    public void notify(User user, Event event) {
        if (user == null || user.getId() == null) {
            return;
        }
        try {
            notifications.sendLocalized(user.getId(), NotificationType.SYSTEM,
                    "notif.twofactor." + event.key() + ".title", "notif.twofactor." + event.key() + ".body", null, null);
        } catch (RuntimeException e) {
            log.warn("2FA bildirimi gonderilemedi userId={} event={}: {}", user.getId(), event, e.toString());
        }
        try {
            Lang lang = Lang.of(user.getLanguage());
            String time = TIME.format(clock.instant().atZone(ZONE));
            mail.sendTwoFactorNotice(user.getEmail(), i18n.msg("mail.twofactor." + event.key(), lang, time), lang);
        } catch (RuntimeException e) {
            log.warn("2FA e-postasi kuyruga yazilamadi userId={} event={}: {}", user.getId(), event, e.toString());
        }
    }
}
