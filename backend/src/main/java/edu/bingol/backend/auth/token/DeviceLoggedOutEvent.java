package edu.bingol.backend.auth.token;

/** Kullanici bu cihazdan cikis yapti ve cihazin FCM token'ini bildirdi (push kaydi silinir). */
public record DeviceLoggedOutEvent(Long userId, String fcmToken) {
}
