package edu.bingol.backend.accessban;

/**
 * Kullanicinin erisimi engellendi: acik WebSocket baglantilari ACCESS_BLOCKED kodu ile kapatilir, FCM cihaz
 * kayitlari silinir. Oturum iptalinden ({@code SessionService.revokeAll}) ONCE yayimlanir.
 */
public record AccessBlockedEvent(Long userId) {
}
