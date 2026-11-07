package edu.bingol.backend.auth.session;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.EventListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Yeni cihaz girisi uyarisi: kullanicinin BASKA acik oturumu varsa uygulama ici bildirim + push (kullanicinin tum
 * cihazlarina; SYSTEM turu: tercihlerden ve sessiz saatten bagimsiz, guvenlik) ve `SECURITY_NEW_LOGIN` e-postasi
 * gider. Gurultu onlemi: (1) bilinen cihaz (ayni cihaz ozeti baska oturumda daha once goruldu) yeni sayilmaz,
 * (2) ayni cihaz icin 10 dk icinde ikinci uyari yok. Hata girisi bozmaz.
 */
@Component
public class NewDeviceNotifier {

    private static final Logger log = LoggerFactory.getLogger(NewDeviceNotifier.class);
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final Duration DEDUPE = Duration.ofMinutes(10);

    private final UserSessionService sessions;
    private final UserRepository users;
    private final NotificationService notifications;
    private final MailService mail;
    private final StringRedisTemplate redis;

    /** Eski tek mobil oturum kurali acikken e-postayi NewLoginNotifier gonderir (ikiye katlanmasin). */
    @Value("${app.auth.single-mobile-session:false}")
    private boolean singleMobileSession = false;

    @Autowired
    public NewDeviceNotifier(UserSessionService sessions, UserRepository users, NotificationService notifications,
                             MailService mail, StringRedisTemplate redis) {
        this.sessions = sessions;
        this.users = users;
        this.notifications = notifications;
        this.mail = mail;
        this.redis = redis;
    }

    void setSingleMobileSession(boolean v) {
        this.singleMobileSession = v;
    }

    @EventListener
    public void onNewSession(NewSessionEvent e) {
        try {
            if (!sessions.hasOtherActive(e.userId(), e.sid())
                    || sessions.knownDevice(e.userId(), e.deviceHash(), e.client(), e.deviceName(), e.ipMasked(), e.sid())) {
                return;
            }
            if (!firstInWindow(e)) {
                return;
            }
            String device = e.deviceName() != null ? e.deviceName()
                    : "mobile".equals(e.client()) ? "BÜ Kampüs (mobil)" : "Web";
            String time = TIME.format(ZonedDateTime.now(ZONE));
            try {
                // Anahtar `notif.session.newdevice.title|body` ({0} cihaz, {1} zaman); tum cihazlara push gider
                notifications.sendTemplated(e.userId(), NotificationType.SYSTEM, "notif.session.newdevice",
                        Map.of("target", "SECURITY", "value", "devices", "securityKind", "NEW_DEVICE",
                                "sessionId", e.sid()),
                        device, time);
            } catch (RuntimeException ex) {
                log.warn("Yeni cihaz bildirimi gonderilemedi (user {}): {}", e.userId(), ex.toString());
            }
            if (!singleMobileSession) {
                users.findById(e.userId()).ifPresent(u -> mail.sendNewLoginAlert(u.getEmail(), device, time,
                        Lang.of(u.getLanguage())));
            }
        } catch (RuntimeException ex) {
            log.warn("Yeni cihaz uyarisi islenemedi (user {}): {}", e.userId(), ex.toString());
        }
    }

    /** Ayni cihaz icin 10 dk penceresinde ilk uyari mi? Redis yoksa/hata verirse uyari engellenmez. */
    private boolean firstInWindow(NewSessionEvent e) {
        String id = e.deviceHash() != null ? e.deviceHash()
                : Hashing.sha256(String.valueOf(e.deviceName()) + "|" + e.ipMasked());
        try {
            return Boolean.TRUE.equals(redis.opsForValue().setIfAbsent("newdev:" + e.userId() + ":" + id, "1", DEDUPE));
        } catch (RuntimeException ex) {
            return true;
        }
    }
}
