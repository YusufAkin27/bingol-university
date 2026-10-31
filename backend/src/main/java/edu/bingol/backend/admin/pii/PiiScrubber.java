package edu.bingol.backend.admin.pii;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Yonetici yanitlarinda kisisel veri kalintisi temizleyici (T-018, ikinci savunma hatti). Maskeleme birincil olarak
 * DTO fabrikalarinda ({@code PermissionAwareMasking}) yapilir; bu sinif yeni/unutulmus bir uctan ya da serbest metinden
 * (ornek: destek mesaji, denetim ozeti) sizan e-posta ve IP/cihaz alanlarini `users.pii` olmayan profiller icin siler.
 * Saf fonksiyon: istek baglami gerektirmez, bagimsiz testlenir.
 */
public final class PiiScrubber {

    /** Ilk karakter + "***" + "@alan" ({@code PermissionAwareMasking.maskEmail} ile ayni bicim; maskeli girdi degismez). */
    private static final Pattern EMAIL = Pattern.compile("([A-Za-z0-9._%+\\-])[A-Za-z0-9._%+\\-]*@([A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)+)");

    /** Degeri tamamen gizlenen alan adlari (kucuk harf): IP ve cihaz kimligi. */
    private static final Set<String> OPAQUE_KEYS = Set.of("ip", "ipaddress", "ip_address", "clientip", "remoteip",
            "lastip", "firstip", "remoteaddr", "devicehash", "deviceid", "deviceshort");

    private PiiScrubber() {}

    /** Ayrik duz yapi (Map/List/String/sayi...) uzerinde temizler; yeni yapi doner, girdiyi degistirmez. */
    public static Object scrub(Object node) {
        return scrub(node, null);
    }

    private static Object scrub(Object node, String key) {
        if (node instanceof Map<?, ?> m) {
            Map<String, Object> out = new LinkedHashMap<>();
            for (Map.Entry<?, ?> e : m.entrySet()) {
                String k = String.valueOf(e.getKey());
                out.put(k, scrub(e.getValue(), k));
            }
            return out;
        }
        if (node instanceof List<?> l) {
            List<Object> out = new ArrayList<>(l.size());
            for (Object o : l) {
                out.add(scrub(o, key));
            }
            return out;
        }
        if (node instanceof String s) {
            if (key != null && OPAQUE_KEYS.contains(key.toLowerCase(Locale.ROOT)) && !s.isEmpty()) {
                return "***";
            }
            return maskEmails(s);
        }
        return node;
    }

    /** Metindeki her e-posta adresini "a***@alan" yapar. */
    public static String maskEmails(String s) {
        if (s == null || s.indexOf('@') < 0) {
            return s;
        }
        Matcher m = EMAIL.matcher(s);
        StringBuilder sb = new StringBuilder();
        while (m.find()) {
            m.appendReplacement(sb, Matcher.quoteReplacement(m.group(1) + "***@" + m.group(2)));
        }
        m.appendTail(sb);
        return sb.toString();
    }
}
