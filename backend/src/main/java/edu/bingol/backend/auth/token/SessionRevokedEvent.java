package edu.bingol.backend.auth.token;

/**
 * Tek bir oturum (sid) kapatildi ("Cihazlarim"dan cikis ya da normal cikis). WebSocket o oturumun baglantisini
 * kapatir, bildirim modulu o oturumdan kaydolmus FCM cihazini siler. Diger cihazlar etkilenmez.
 */
public record SessionRevokedEvent(Long userId, String sid) {
}
