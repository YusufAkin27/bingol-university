package edu.bingol.backend.auth.token;

/**
 * Oturumlar iptal edildi; WebSocket, cihaz temizligi ve guvenlik e-postasi tarafi dinler.
 * `client` null = tum istemciler (sifre degisimi, "tum cihazlardan cik"); "mobile" = yalniz mobil oturumlar.
 * `newLogin`: iptal, baska bir cihazdaki yeni girisin sonucudur (tek cihaz kurali); `hadSessions`: iptal edilen
 * en az bir refresh oturumu vardi.
 */
public record SessionsRevokedEvent(Long userId, String client, boolean newLogin, boolean hadSessions) {

    public SessionsRevokedEvent(Long userId) {
        this(userId, null, false, false);
    }
}
