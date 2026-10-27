package edu.bingol.backend.legal;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Sozlesme metnindeki yer tutucu doldurma (saf fonksiyon, test edilebilir).
 * <ul>
 *   <li>{@code {{anahtar}}}: deger varsa yazilir, yoksa bos birakilir</li>
 *   <li>{@code {{anahtar|yedek metin}}}: deger bossa yedek metin yazilir</li>
 *   <li>{@code {{?anahtar}}...{{/anahtar}}}: blok yalniz deger doluysa tutulur (kimlik satirlari icin)</li>
 * </ul>
 * Bilinmeyen/bos anahtar yer tutucu olarak GORUNMEZ; kullaniciya ham "{{...}}" gosterilmez.
 */
public final class LegalTemplate {

    /** Satir basindaki blok: kaldirilirsa satirin sonundaki yeni satir da gider (tablo/liste satiri bozulmasin). */
    private static final Pattern LINE_BLOCK = Pattern.compile(
            "^\\{\\{\\?([A-Za-z0-9_.]+)\\}\\}(.*?)\\{\\{/\\1\\}\\}[ \\t]*(?:\\n|\\z)", Pattern.DOTALL | Pattern.MULTILINE);
    private static final Pattern BLOCK = Pattern.compile("\\{\\{\\?([A-Za-z0-9_.]+)\\}\\}(.*?)\\{\\{/\\1\\}\\}",
            Pattern.DOTALL);
    private static final Pattern VAR = Pattern.compile("\\{\\{([A-Za-z0-9_.]+)(?:\\|([^{}]*))?\\}\\}");

    private LegalTemplate() {}

    public static String render(String text, Map<String, String> values) {
        if (text == null || !text.contains("{{")) {
            return text;
        }
        String cur = replaceBlocks(LINE_BLOCK, text, values, true);
        cur = replaceBlocks(BLOCK, cur, values, false);
        Matcher v = VAR.matcher(cur);
        StringBuilder out = new StringBuilder();
        while (v.find()) {
            String val = has(values, v.group(1)) ? values.get(v.group(1)).trim()
                    : (v.group(2) == null ? "" : v.group(2).trim());
            v.appendReplacement(out, Matcher.quoteReplacement(val));
        }
        v.appendTail(out);
        // Silinen bloklardan kalan bos satirlari toparla
        return out.toString().replaceAll("[ \\t]+\\n", "\n").replaceAll("\\n{3,}", "\n\n").trim();
    }

    private static String replaceBlocks(Pattern p, String in, Map<String, String> values, boolean line) {
        Matcher m = p.matcher(in);
        StringBuilder sb = new StringBuilder();
        while (m.find()) {
            String keep = has(values, m.group(1)) ? m.group(2) + (line ? "\n" : "") : "";
            m.appendReplacement(sb, Matcher.quoteReplacement(keep));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    private static boolean has(Map<String, String> values, String key) {
        String v = values.get(key);
        return v != null && !v.isBlank();
    }
}
