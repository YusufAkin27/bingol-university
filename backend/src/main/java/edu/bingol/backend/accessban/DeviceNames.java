package edu.bingol.backend.accessban;

import java.util.Locale;

/**
 * "Cihazlarim" icin gorunen cihaz adi: istemci `X-Device-Name` gonderdiyse o (temizlenmis), yoksa User-Agent'tan
 * kaba bir ad ("Android", "iPhone", "Chrome / Windows"...). Yalniz gorunum icindir; kimlik/guvenlik karari vermez.
 */
public final class DeviceNames {

    public static final int MAX_LENGTH = 80;

    private DeviceNames() {}

    /** Kontrol karakterleri ve `<>` temizlenir, bosluklar sadelesir, en cok 80 karakter; bos kalirsa null. */
    public static String sanitize(String raw) {
        if (raw == null) {
            return null;
        }
        StringBuilder b = new StringBuilder(raw.length());
        for (int i = 0; i < raw.length() && b.length() < MAX_LENGTH * 2; i++) {
            char c = raw.charAt(i);
            if (Character.isISOControl(c) || c == '<' || c == '>' || c == '"' || c == '\\' || c == '`') {
                b.append(' ');
            } else {
                b.append(c);
            }
        }
        String s = b.toString().replaceAll("\\s+", " ").trim();
        if (s.length() > MAX_LENGTH) {
            s = s.substring(0, MAX_LENGTH).trim();
        }
        return s.isEmpty() ? null : s;
    }

    /** Baslik adi > User-Agent turevi > platform adi > null. */
    public static String resolve(String nameHeader, String userAgent, String platform) {
        String named = sanitize(nameHeader);
        if (named != null) {
            return named;
        }
        String fromUa = fromUserAgent(userAgent);
        if (fromUa != null) {
            return fromUa;
        }
        if (platform != null) {
            switch (platform.trim().toUpperCase(Locale.ROOT)) {
                case "ANDROID":
                    return "Android";
                case "IOS":
                    return "iPhone";
                case "WEB":
                    return "Web";
                default:
                    return null;
            }
        }
        return null;
    }

    static String fromUserAgent(String ua) {
        if (ua == null || ua.isBlank()) {
            return null;
        }
        String u = ua.toLowerCase(Locale.ROOT);
        String os = u.contains("iphone") ? "iPhone"
                : u.contains("ipad") ? "iPad"
                : u.contains("android") ? "Android"
                : u.contains("windows") ? "Windows"
                : u.contains("mac os") || u.contains("macintosh") ? "macOS"
                : u.contains("linux") ? "Linux" : null;
        // Dart/Flutter HTTP istemcisi tarayici degildir: yalniz isletim sistemi
        String browser = u.contains("edg/") ? "Edge"
                : u.contains("opr/") || u.contains("opera") ? "Opera"
                : u.contains("chrome/") || u.contains("crios") ? "Chrome"
                : u.contains("firefox/") || u.contains("fxios") ? "Firefox"
                : u.contains("safari/") ? "Safari" : null;
        if (browser != null && os != null) {
            return browser + " / " + os;
        }
        return browser != null ? browser : os;
    }
}
