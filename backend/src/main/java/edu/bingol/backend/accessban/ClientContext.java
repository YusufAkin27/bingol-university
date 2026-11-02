package edu.bingol.backend.accessban;

/**
 * Istek sahibinin ag/cihaz bilgisi. `deviceHash` istemcinin X-Device-Id degerinin HMAC ozetidir (baslik yoksa ya da
 * gecersizse null; ham deger hicbir yerde tutulmaz). `ip` ClientIp ile cozulmus istemci adresidir. `deviceModel`
 * istemcinin istege bagli `X-Device-Model` basligidir (yeni cihaz bildiriminde gosterilir; saklanmaz, temizlenmis metin).
 */
public record ClientContext(String ip, String deviceHash, String platform, String appVersion, String deviceModel) {

    public static final String REQUEST_ATTR = "accessban.clientContext";

    /** Cihaz modeli olmayan (eski) 4 alanli kurucu. */
    public ClientContext(String ip, String deviceHash, String platform, String appVersion) {
        this(ip, deviceHash, platform, appVersion, null);
    }

    public boolean hasDevice() {
        return deviceHash != null;
    }
}
