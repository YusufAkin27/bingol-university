package edu.bingol.backend.auth.token;

/**
 * Kullanici bu cihazdan cikis yapti: istemci FCM token'ini bildirdiyse o kayit silinir; ek olarak (varsa) oturum
 * kimligiyle (sid) bu oturumdan kaydolmus cihaz kaydi da silinir. Diger oturumlarin cihazlari korunur.
 */
public record DeviceLoggedOutEvent(Long userId, String fcmToken, String sid) {

    public DeviceLoggedOutEvent(Long userId, String fcmToken) {
        this(userId, fcmToken, null);
    }
}
