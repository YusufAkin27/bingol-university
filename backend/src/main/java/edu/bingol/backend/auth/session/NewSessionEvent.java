package edu.bingol.backend.auth.session;

/** Yeni bir giris (yeni sid) acildi; yeni cihaz bildirimi dinler. Yenileme/devralma bu olayi uretmez. */
public record NewSessionEvent(Long userId, String sid, String client, String platform, String deviceName,
                              String deviceHash, String ipMasked) {
}
