package edu.bingol.backend.crash;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.observability.LogMasking;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Cokme raporlarindaki metni sunucuda ikinci kez maskeler (istemciye guvenilmez) ve hata imzasini uretir.
 * Saf fonksiyonlar; birim testlidir. Yigin izinde dosya yollari ve kare adlari KALIR; e-posta, jeton, sorgu dizesi,
 * uzun sayilar (ogrenci no, telefon) ve ev dizinindeki kullanici adi temizlenir.
 */
public final class CrashScrubber {

    static final int MAX_STACK_CHARS = 8000;
    static final int MAX_STACK_LINES = 60;
    static final int MAX_LINE_CHARS = 300;
    static final int SIGNATURE_FRAMES = 8;

    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    private static final Pattern URL_QUERY = Pattern.compile("(?i)(https?://[^\\s?#\"'<>)]*)[?#][^\\s\"'<>)]*");
    private static final Pattern UUID = Pattern.compile(
            "(?i)\\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\b");
    /** 32+ karakterlik, hem harf hem rakam iceren dizi: jeton/anahtar olabilir. Uzun tanimlayicilar (yalniz harf) korunur. */
    private static final Pattern LONG_TOKEN = Pattern.compile("(?<![A-Za-z0-9_-])(?=[A-Za-z0-9_-]*\\d)(?=[A-Za-z0-9_-]*[A-Za-z])[A-Za-z0-9_-]{32,}");
    private static final Pattern LONG_DIGITS = Pattern.compile("(?<![\\w.:])\\d{7,}(?![\\w.])");
    private static final Pattern HOME_DIR = Pattern.compile("(?i)(/Users/|/home/|[A-Z]:\\\\Users\\\\)[^/\\\\\\s)]+");
    private static final Pattern ANDROID_USER = Pattern.compile("/data/(?:user|data)/\\d+/");
    private static final Pattern CONTROL = Pattern.compile("[\\p{Cntrl}&&[^\\n\\t]]");

    // Imza normalizasyonu
    private static final Pattern FRAME_INDEX = Pattern.compile("^\\s*#\\d+\\s+");
    private static final Pattern LINE_COL = Pattern.compile(":\\d+(?::\\d+)?(?=\\)|\\s|$)");
    private static final Pattern HEX_ADDR = Pattern.compile("(?i)\\b(?:0x)?[0-9a-f]{8,}\\b");
    private static final Pattern ABS_PC = Pattern.compile("(?i)\\babs\\s+[0-9a-f]+\\b|\\bvirt\\s+[0-9a-f]+\\b");
    private static final Pattern WS = Pattern.compile("\\s+");

    private CrashScrubber() {
    }

    /** Tek satir/serbest metin alani (hata iletisi, ekran adi, model). Bos ise null. */
    public static String text(String raw, int max) {
        if (raw == null) {
            return null;
        }
        String s = clean(raw).replace('\n', ' ').replace('\t', ' ');
        s = WS.matcher(s).replaceAll(" ").strip();
        if (s.isEmpty()) {
            return null;
        }
        return s.length() > max ? s.substring(0, max) : s;
    }

    /** Yigin izi: satir/karakter sinirli ve maskeli. */
    public static String stack(String raw) {
        if (raw == null) {
            return "";
        }
        String[] lines = raw.replace("\r", "").split("\n");
        List<String> out = new ArrayList<>();
        for (String line : lines) {
            if (out.size() >= MAX_STACK_LINES) {
                break;
            }
            String s = clean(line).stripTrailing();
            if (s.isBlank()) {
                continue;
            }
            out.add(s.length() > MAX_LINE_CHARS ? s.substring(0, MAX_LINE_CHARS) : s);
        }
        String joined = String.join("\n", out);
        return joined.length() > MAX_STACK_CHARS ? joined.substring(0, MAX_STACK_CHARS) : joined;
    }

    /** Ortak maskeleme zinciri. */
    static String clean(String raw) {
        String s = CONTROL.matcher(raw).replaceAll("");
        s = EMAIL.matcher(s).replaceAll("[eposta]");
        s = URL_QUERY.matcher(s).replaceAll("$1?[gizli]");
        s = UUID.matcher(s).replaceAll("[uuid]");
        s = HOME_DIR.matcher(s).replaceAll("$1[kullanici]");
        s = ANDROID_USER.matcher(s).replaceAll("/data/user/_/");
        s = LogMasking.scrub(s); // JWT, Bearer, parola/jeton/kod anahtar-deger
        s = LONG_TOKEN.matcher(s).replaceAll("[gizli]");
        s = LONG_DIGITS.matcher(s).replaceAll("[sayi]");
        return s;
    }

    /** Hata imzasi: tur + ilk N normalize kare (satir/sutun, adres, sira numarasi olmadan), SHA-256 hex. */
    public static String signature(String errorType, String stack) {
        StringBuilder sb = new StringBuilder(errorType == null ? "" : errorType.strip());
        int n = 0;
        if (stack != null) {
            for (String line : stack.split("\n")) {
                String f = normalizeFrame(line);
                if (f.isEmpty()) {
                    continue;
                }
                sb.append('|').append(f);
                if (++n >= SIGNATURE_FRAMES) {
                    break;
                }
            }
        }
        return Hashing.sha256(sb.toString());
    }

    /** Ilk anlamli yigin karesi (listede gostermek icin); yoksa null. */
    public static String topFrame(String stack) {
        if (stack == null) {
            return null;
        }
        for (String line : stack.split("\n")) {
            String f = FRAME_INDEX.matcher(line).replaceFirst("").strip();
            if (!f.isEmpty() && (f.contains("package:") || f.contains("(") || f.contains(".dart"))) {
                return f.length() > 300 ? f.substring(0, 300) : f;
            }
        }
        return null;
    }

    static String normalizeFrame(String line) {
        String s = FRAME_INDEX.matcher(line).replaceFirst("");
        s = ABS_PC.matcher(s).replaceAll("");
        s = HEX_ADDR.matcher(s).replaceAll("");
        s = LINE_COL.matcher(s).replaceAll("");
        s = WS.matcher(s).replaceAll(" ").strip();
        return s.toLowerCase(Locale.ROOT).startsWith("<asynchronous suspension>") ? "" : s;
    }

    /**
     * Surum karsilastirmasi ("1.2.10" > "1.2.9", "+build" ve "-onsurum" yoksayilir). Sayisal olmayan parca 0 sayilir.
     * Negatif: a &lt; b.
     */
    public static int compareVersions(String a, String b) {
        int[] x = parts(a);
        int[] y = parts(b);
        for (int i = 0; i < Math.max(x.length, y.length); i++) {
            int p = i < x.length ? x[i] : 0;
            int q = i < y.length ? y[i] : 0;
            if (p != q) {
                return Integer.compare(p, q);
            }
        }
        return 0;
    }

    private static int[] parts(String v) {
        if (v == null) {
            return new int[0];
        }
        String core = v.strip();
        int cut = core.indexOf('+');
        if (cut >= 0) {
            core = core.substring(0, cut);
        }
        cut = core.indexOf('-');
        if (cut >= 0) {
            core = core.substring(0, cut);
        }
        String[] seg = core.split("\\.");
        int[] out = new int[seg.length];
        for (int i = 0; i < seg.length; i++) {
            try {
                out[i] = Integer.parseInt(seg[i].replaceAll("\\D", ""));
            } catch (NumberFormatException e) {
                out[i] = 0;
            }
        }
        return out;
    }
}
