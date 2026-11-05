package edu.bingol.backend.notification;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/**
 * Bildirim tasarimi yuk alanlari (docs/changes/push.md "Bildirim tasarimi yuk sozlesmesi"). Uretici bu anahtarlari
 * `data` haritasina koyar; {@link NotificationService} push yukune aynen ekler, bildirim kutusuna (kalici `data` JSON)
 * ise {@link #PUSH_ONLY} anahtarlar YAZILMAZ (avatar/gorsel/kaynak adi istek aninda gizlilik suzgeciyle uretilir).
 */
public final class PushDisplay {

    /** Kalici `data`ya yazilmayan, yalniz push yukunde gezen anahtarlar. `badgeKey` cozulunce `badgeText` olur. */
    static final Set<String> PUSH_ONLY = Set.of("imageUrl", "senderAvatarUrl", "sourceName", "badgeKey");

    /** Gecerli `badgeKey` degerleri (`notif.badge.<anahtar>` i18n). */
    public static final String BADGE_TOMORROW = "tomorrow";
    public static final String BADGE_TIME_REVISION = "timeRevision";
    public static final String BADGE_CANCELLED = "cancelled";
    public static final String BADGE_LAST_24H = "last24h";
    public static final String BADGE_IMPORTANT = "important";

    private PushDisplay() {}

    /** Kalici `data` icin: yalniz-push anahtarlar atilir. */
    public static Map<String, String> stored(Map<String, String> data) {
        if (data == null || data.isEmpty()) {
            return data;
        }
        boolean any = false;
        for (String k : PUSH_ONLY) {
            if (data.containsKey(k)) {
                any = true;
                break;
            }
        }
        if (!any) {
            return data;
        }
        Map<String, String> out = new LinkedHashMap<>(data);
        PUSH_ONLY.forEach(out::remove);
        return out;
    }

    /** `badgeKey`i alicinin dilinde `badgeText`e cevirir (anahtar yoksa harita degismez). */
    public static Map<String, String> withBadge(Map<String, String> data, I18n i18n, Lang lang) {
        if (data == null || !data.containsKey("badgeKey")) {
            return data;
        }
        Map<String, String> out = new LinkedHashMap<>(data);
        String key = out.remove("badgeKey");
        if (key != null && !key.isBlank() && i18n != null) {
            String text = i18n.msg("notif.badge." + key, lang);
            if (text != null && !text.isBlank() && !text.equals("notif.badge." + key)) {
                out.put("badgeText", text);
            }
        }
        return out;
    }

    /** ISO-8601 UTC an (saniye duyarliligi); null icin null. */
    public static String iso(Instant t) {
        return t == null ? null : t.truncatedTo(ChronoUnit.SECONDS).toString();
    }

    /** Bos olmayan degeri yazar; uzunsa kirpar. */
    public static void put(Map<String, String> m, String key, String value, int max) {
        if (value == null || value.isBlank()) {
            return;
        }
        String v = value.trim();
        m.put(key, v.length() <= max ? v : v.substring(0, max - 1) + "…");
    }
}
