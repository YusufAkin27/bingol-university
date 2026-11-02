package edu.bingol.backend.analytics.usage;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Ozellik benimseme tablosunun ozellik -> ekran/eylem anahtari eslemesi. Bir anahtar (screen_view'de ekran, diger
 * olaylarda olay adi) ozellik oneklerinden biriyle ya da "onek_" ile basliyorsa o ozelligi kullanilmis sayilir.
 * Yeni ekran/eylem anahtari eklendiginde yalniz burasi guncellenir; SQL buradan uretilir (sabit metin).
 */
public final class UsageFeatures {

    /** Tum olay gonderen kullanicilar (payda ile kiyaslama icin). */
    public static final String ALL = "all";

    public static final Map<String, List<String>> PREFIXES = new LinkedHashMap<>();

    static {
        PREFIXES.put("news", List.of("news", "announcement", "announcements", "saved_news", "unit_news"));
        PREFIXES.put("menu", List.of("menu"));
        PREFIXES.put("events", List.of("event", "events", "my_events"));
        PREFIXES.put("clubs", List.of("club", "clubs", "my_clubs", "community"));
        PREFIXES.put("chat", List.of("chat", "message", "new_chat"));
        PREFIXES.put("map", List.of("campus_map", "map"));
        PREFIXES.put("polls", List.of("poll", "polls"));
        PREFIXES.put("academic", List.of("academic", "exam", "exams", "timetable", "course"));
        PREFIXES.put("search", List.of("search"));
    }

    private UsageFeatures() {
    }

    /** Anahtarin ozelligi ya da null (testler ve dogrulama icin; SQL ile ayni kural). */
    public static String featureOf(String key) {
        if (key == null) {
            return null;
        }
        for (Map.Entry<String, List<String>> e : PREFIXES.entrySet()) {
            for (String p : e.getValue()) {
                if (key.equals(p) || key.startsWith(p + "_")) {
                    return e.getKey();
                }
            }
        }
        return null;
    }

    /** {@code keyExpr} sutun ifadesi icin SQL CASE: ozellik adi ya da NULL. Yalniz sabit metinlerden olusur. */
    public static String sqlCase(String keyExpr) {
        StringBuilder sb = new StringBuilder("CASE");
        for (Map.Entry<String, List<String>> e : PREFIXES.entrySet()) {
            sb.append(" WHEN ");
            boolean first = true;
            for (String p : e.getValue()) {
                if (!first) {
                    sb.append(" OR ");
                }
                first = false;
                sb.append('(').append(keyExpr).append(" = '").append(p).append("' OR starts_with(")
                        .append(keyExpr).append(", '").append(p).append("_'))");
            }
            sb.append(" THEN '").append(e.getKey()).append('\'');
        }
        return sb.append(" END").toString();
    }
}
