package edu.bingol.backend.observability;

import java.util.regex.Pattern;

/** Log ve yonetici panelinde kisisel veri/sir gostermemek icin maskeleme yardimcilari. */
public final class LogMasking {

    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    private static final Pattern BEARER = Pattern.compile("(?i)bearer\\s+[A-Za-z0-9._~+/=-]+");
    private static final Pattern JWT = Pattern.compile("eyJ[A-Za-z0-9_-]{5,}\\.[A-Za-z0-9_-]{5,}\\.[A-Za-z0-9_-]*");
    private static final Pattern SECRET_KV = Pattern.compile(
            "(?i)(password|passwd|sifre|secret|token|authorization|code)([\"'=:\\s]+)([^\\s\"',;&]+)");

    private LogMasking() {
    }

    /** "ali.veli@bingol.edu.tr" -> "a***@bingol.edu.tr". */
    public static String email(String address) {
        if (address == null || address.isBlank()) {
            return "?";
        }
        int at = address.indexOf('@');
        if (at < 1) {
            return "***";
        }
        return address.charAt(0) + "***" + address.substring(at);
    }

    /** Serbest metindeki e-posta, JWT, Bearer ve parola/token/kod degerlerini maskeler (hata mesajlari icin). */
    public static String scrub(String text) {
        if (text == null) {
            return null;
        }
        String s = JWT.matcher(text).replaceAll("[jwt]");
        s = BEARER.matcher(s).replaceAll("Bearer [gizli]");
        s = SECRET_KV.matcher(s).replaceAll("$1$2[gizli]");
        return EMAIL.matcher(s).replaceAll(m -> java.util.regex.Matcher.quoteReplacement(email(m.group())));
    }
}
