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
 * (eski cihaza bildirim gitmesin). Tum oturumlar kapaninca (logout-all, sifre degisimi/sifirlama, askiya alma) da
 * kullanicinin tum FCM kayitlari silinir. Etkin cihaz `POST /devices` ile kendini yeniden kaydeder.
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
        // (1) tek cihaz kurali: baska mobil cihazdaki yeni giris; (2) TUM oturumlar kapandi (logout-all, sifre
        // degisimi/sifirlama, askiya alma): kilit ekraninda bildirim surmesin (T-008). Etkin cihaz giristen/yeni
        // token'dan sonra kendini POST /devices ile yeniden kaydeder.
        boolean singleDeviceRule = e.newLogin() && "mobile".equals(e.client());
        boolean allSessions = e.client() == null && !e.newLogin();
        if (!singleDeviceRule && !allSessions) {
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
