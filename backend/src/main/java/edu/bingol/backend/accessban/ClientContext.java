package edu.bingol.backend.accessban;

/**
 * Istek sahibinin ag/cihaz bilgisi. `deviceHash` istemcinin X-Device-Id degerinin HMAC ozetidir (baslik yoksa ya da
 * gecersizse null; ham deger hicbir yerde tutulmaz). `ip` ClientIp ile cozulmus istemci adresidir.
 */
public record ClientContext(String ip, String deviceHash, String platform, String appVersion) {

    public static final String REQUEST_ATTR = "accessban.clientContext";

    public boolean hasDevice() {
        return deviceHash != null;
    }
}
