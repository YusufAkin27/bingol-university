package edu.bingol.backend.accessban;

/**
 * Istek sahibinin ag/cihaz bilgisi. `deviceHash` istemcinin X-Device-Id degerinin HMAC ozetidir (baslik yoksa ya da
 * gecersizse null; ham deger hicbir yerde tutulmaz). `ip` ClientIp ile cozulmus istemci adresidir.
 */
public record ClientContext(String ip, String deviceHash, String platform, String appVersion, String deviceName) {

    public static final String REQUEST_ATTR = "accessban.clientContext";

    /** Cihaz adi olmadan (engel/cihaz gunlugu denetimleri). `deviceName`: gorunen ad (X-Device-Name / User-Agent), saklanmaz degil ama Cihazlarim icindir. */
    public ClientContext(String ip, String deviceHash, String platform, String appVersion) {
        this(ip, deviceHash, platform, appVersion, null);
    }

    public boolean hasDevice() {
        return deviceHash != null;
    }
}
