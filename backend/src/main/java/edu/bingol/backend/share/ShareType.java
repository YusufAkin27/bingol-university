package edu.bingol.backend.share;

import java.util.Locale;

/**
 * Paylasilabilir icerik turleri ve herkese acik baglantidaki tek harfli kodlari
 * ({@code https://bukampus.com.tr/s/{kod}/{id}}). POST ve REEL ayni gonderi tablosundan cozulur
 * (REEL = video gonderi; kod yalniz uygulamada hangi sekmede acilacagini soyler).
 */
public enum ShareType {
    POST("p"), REEL("r"), NEWS("n"), EVENT("e");

    private final String code;

    ShareType(String code) {
        this.code = code;
    }

    public String code() {
        return code;
    }

    /** `POST|REEL|NEWS|EVENT` (buyuk/kucuk harf serbest); taninmazsa null. */
    public static ShareType parse(String raw) {
        if (raw == null) {
            return null;
        }
        String v = raw.trim().toUpperCase(Locale.ROOT);
        for (ShareType t : values()) {
            if (t.name().equals(v)) {
                return t;
            }
        }
        return null;
    }

    /** Baglanti kodu (`p|r|n|e`); taninmazsa null. */
    public static ShareType ofCode(String code) {
        if (code == null) {
            return null;
        }
        for (ShareType t : values()) {
            if (t.code.equals(code)) {
                return t;
            }
        }
        return null;
    }

    public boolean isPost() {
        return this == POST || this == REEL;
    }
}
