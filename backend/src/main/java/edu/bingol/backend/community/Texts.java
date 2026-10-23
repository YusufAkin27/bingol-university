package edu.bingol.backend.community;

import java.util.Locale;

/** Topluluk ve etkinlik modullerinin ortak metin yardimcilari. */
public final class Texts {

    private Texts() {}

    /** Turkce karakterleri ASCII'ye cevirip URL dostu slug uretir ("Yazilim Kulubu!" -> "yazilim-kulubu"). */
    public static String slugify(String name) {
        String s = name.trim()
                .replace('ı', 'i').replace('İ', 'i').replace('ş', 's').replace('Ş', 's')
                .replace('ğ', 'g').replace('Ğ', 'g').replace('ü', 'u').replace('Ü', 'u')
                .replace('ö', 'o').replace('Ö', 'o').replace('ç', 'c').replace('Ç', 'c')
                .toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9]+", "-")
                .replaceAll("^-+|-+$", "");
        if (s.length() > 60) {
            s = s.substring(0, 60).replaceAll("-+$", "");
        }
        return s.isEmpty() ? "topluluk" : s;
    }

    /** LIKE/ILIKE deseni: ozel karakterleri '!' ile kacirir, kucuk harfe cevirir; bos girdi icin "" doner (filtre yok). */
    public static String likePattern(String q) {
        if (q == null || q.isBlank()) {
            return "";
        }
        String e = q.trim().toLowerCase(Locale.ROOT)
                .replace("!", "!!").replace("%", "!%").replace("_", "!_");
        return "%" + e + "%";
    }

    /** Bos veya bosluk olan dizgiyi null yapar, aksi halde kirpar. */
    public static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
