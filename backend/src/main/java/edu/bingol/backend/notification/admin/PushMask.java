package edu.bingol.backend.notification.admin;

/** Yonetici push ekranlari icin maskeleme (saf fonksiyonlar). Ham token zaten kuyrukta tutulmaz; yalniz ozeti vardir. */
public final class PushMask {

    private PushMask() {}

    /** Token ozetinin (SHA-256, 64 hane) ilk 8 hanesi; kayitlar arasi eslestirmeye yeter, geri cozulemez. */
    public static String tokenRef(String tokenHash) {
        if (tokenHash == null || tokenHash.length() < 8) {
            return null;
        }
        return tokenHash.substring(0, 8) + "...";
    }

    /** Kullanici kimligi: ilk ve son hane, ortasi maskeli (ornek 12345 -> 1***5); 2 haneden kisaysa tamami maskeli. */
    public static String userRef(Long userId) {
        if (userId == null) {
            return null;
        }
        String s = String.valueOf(userId);
        if (s.length() <= 2) {
            return "***";
        }
        return s.charAt(0) + "***" + s.charAt(s.length() - 1);
    }
}
