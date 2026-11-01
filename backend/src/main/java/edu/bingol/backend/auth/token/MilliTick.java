package edu.bingol.backend.auth.token;

/**
 * Bir sonraki milisaniyeye gecmeyi bekler. Oturum iptal isareti `iatms <= isaret` token'lari reddeder; iptalden hemen
 * sonra uretilecek yeni token'in iatms'i isaretten KESIN buyuk olmali. Eskiden `Thread.sleep(1)` (istek is parcacigini
 * zamanlayiciya birakir, Windows'ta 15 ms'ye varir); burada en cok ~1 ms kisa bekleme.
 */
public final class MilliTick {

    private MilliTick() {
    }

    public static void awaitNext() {
        long t = System.currentTimeMillis();
        while (System.currentTimeMillis() == t) {
            Thread.onSpinWait();
        }
    }
}
