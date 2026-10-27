package edu.bingol.backend.post.social;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Metin ayristiricilari (saf, durumsuz): @[Ad Soyad](uid:123) etiketleri ve #etiketler.
 * Turkce kurallar: buyuk I -> i degil 1 (dotless) degil; "tr" yerelinde I -> ı, İ -> i. Arama anahtari aksansizdir
 * (ı->i, ş->s, ğ->g, ü->u, ö->o, ç->c).
 */
public final class SocialText {

    public static final int MAX_MENTIONS = 10;
    public static final int MAX_HASHTAGS = 10;
    public static final int TAG_MIN = 2;
    public static final int TAG_MAX = 40;

    private static final Locale TR = Locale.forLanguageTag("tr");

    /** @[Gorunen Ad](uid:123): ad koseli parantez ve satir sonu icermez. */
    private static final Pattern MENTION = Pattern.compile("@\\[([^\\]\\r\\n]{1,80})\\]\\(uid:(\\d{1,18})\\)");

    /** #etiket: oncesinde harf/rakam/_/&/ olmamali (URL parcasi, e-posta vb. etiket sayilmaz); 2-40 karakter. */
    private static final Pattern HASHTAG = Pattern.compile(
            "(?<![\\p{L}\\p{N}_&/#])#([\\p{L}\\p{N}_]{" + TAG_MIN + "," + TAG_MAX + "})(?![\\p{L}\\p{N}_])");

    private SocialText() {}

    /** Metindeki tum etiket sayisi (tekrarlar dahil) - 10 siniri icin. */
    public static int countMentions(String text) {
        if (text == null) {
            return 0;
        }
        Matcher m = MENTION.matcher(text);
        int n = 0;
        while (m.find()) {
            n++;
        }
        return n;
    }

    /** Benzersiz kullanici kimlikleri (gorulme sirasiyla), en cok {@link #MAX_MENTIONS}. */
    public static List<Long> mentionedIds(String text) {
        Set<Long> ids = new LinkedHashSet<>();
        if (text == null) {
            return List.of();
        }
        Matcher m = MENTION.matcher(text);
        while (m.find() && ids.size() < MAX_MENTIONS) {
            try {
                ids.add(Long.parseLong(m.group(2)));
            } catch (NumberFormatException ignored) {
                // tasan sayi: yok say
            }
        }
        return new ArrayList<>(ids);
    }

    /** Etiket bicimlerini ayiklar (hashtag taramasinda gorunen ad icindeki # etkilemesin diye). */
    public static String stripMentions(String text) {
        return text == null ? "" : MENTION.matcher(text).replaceAll(" ");
    }

    /** Arama anahtari -> gorunen ad (ilk gorulen); en cok 10, yalniz rakamdan olusanlar atilir. */
    public static Map<String, String> hashtags(String text) {
        Map<String, String> out = new LinkedHashMap<>();
        if (text == null || text.isEmpty()) {
            return out;
        }
        Matcher m = HASHTAG.matcher(stripMentions(text));
        while (m.find() && out.size() < MAX_HASHTAGS) {
            String display = display(m.group(1));
            if (display.chars().allMatch(Character::isDigit)) {
                continue;
            }
            out.putIfAbsent(fold(display), display);
        }
        return out;
    }

    /** Turkce kurallarla kucuk harf (I -> ı, İ -> i). */
    public static String display(String raw) {
        return raw.toLowerCase(TR);
    }

    /** Aksansiz arama anahtari; kullanici girdisi ("#Ataturk", "ATATÜRK") ayni anahtara iner. */
    public static String fold(String raw) {
        String s = raw == null ? "" : raw.strip();
        if (s.startsWith("#")) {
            s = s.substring(1);
        }
        s = s.toLowerCase(TR);
        StringBuilder b = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            b.append(switch (c) {
                case 'ı', 'î', 'í', 'ì' -> 'i';
                case 'ş' -> 's';
                case 'ğ' -> 'g';
                case 'ü', 'û', 'ú', 'ù' -> 'u';
                case 'ö', 'ô', 'ó', 'ò' -> 'o';
                case 'ç' -> 'c';
                case 'â', 'á', 'à' -> 'a';
                case 'é', 'è', 'ê' -> 'e';
                default -> c;
            });
        }
        return b.toString();
    }

    /** Gecerli etiket (aranan/onerilen) mi: 2-40 harf/rakam/_. */
    public static boolean validTag(String raw) {
        if (raw == null) {
            return false;
        }
        String s = raw.startsWith("#") ? raw.substring(1) : raw;
        return s.length() >= TAG_MIN && s.length() <= TAG_MAX && s.matches("[\\p{L}\\p{N}_]+");
    }
}
