package edu.bingol.backend.notification;

import edu.bingol.backend.accessban.AccessBlockedEvent;
import edu.bingol.backend.auth.token.DeviceLoggedOutEvent;
import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Tek cihaz kurali: baska bir mobil cihazdaki yeni giris eski oturumu kapatinca eski cihazin FCM kaydi da silinir
 * (eski cihaza bildirim gitmesin). Yeni cihaz giristen sonra `POST /devices` ile kendini yeniden kaydeder.
 */
@Component
public class SessionDeviceCleaner {

    private static final Logger log = LoggerFactory.getLogger(SessionDeviceCleaner.class);

    private final DeviceRepository devices;

    public SessionDeviceCleaner(DeviceRepository devices) {
        this.devices = devices;
    }

    @EventListener
    public void onSessionsRevoked(SessionsRevokedEvent e) {
        if (!e.newLogin() || !"mobile".equals(e.client())) {
            return;
        }
        try {
            devices.deleteAllByUser(e.userId());
        } catch (RuntimeException ex) {
            // Giris akisini bozmaz; kayitlar 60 gunluk temizlikte de duser.
            log.warn("Cihaz kayitlari silinemedi (user {}): {}", e.userId(), ex.toString());
        }
    }

    /** Cikis (istemci FCM token'ini gonderdiyse): yalniz bu kullanicinin o token kaydi silinir. */
    @EventListener
    public void onDeviceLoggedOut(DeviceLoggedOutEvent e) {
        try {
            devices.deleteByFcmTokenAndUserId(e.fcmToken(), e.userId());
        } catch (RuntimeException ex) {
            log.warn("Cikis yapan cihaz kaydi silinemedi (user {}): {}", e.userId(), ex.toString());
        }
    }

    /** Erisim engeli: kullanicinin FCM kayitlari silinir (engelli hesaba bildirim gitmesin). */
    @EventListener
    public void onAccessBlocked(AccessBlockedEvent e) {
        try {
            devices.deleteAllByUser(e.userId());
        } catch (RuntimeException ex) {
            log.warn("Engellenen kullanicinin cihaz kayitlari silinemedi (user {}): {}", e.userId(), ex.toString());
        }
    }
}
