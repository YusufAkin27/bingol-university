package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.moderation.spi.ForumTextSanitizer;
import java.util.regex.Pattern;

/**
 * Forum konu metni temizligi: {@link ForumTextSanitizer}'a ince bir cephe (QA5-10: konu, yorum ve gerekce icin TEK
 * temizleyici; onceden uc ayri uygulama vardi). Cikti JSON duz metindir; istemci HTML yorumlamaz, bu temizlik ikinci
 * savunma hattidir. Birlestirme ile konu metni de kazandi: NFC, script/style blogu ve yorum silme, bidi/gorunmez
 * karakter (soft hyphen dahil), "javascript:" gibi duz metin korunur.
 */
public final class ForumText {

    private static final Pattern SPACES = Pattern.compile("[ \t\u00A0]+");

    private ForumText() {}

    /** Tek satir (baslik): tum bosluklar tek bosluga iner. */
    public static String line(String s) {
        return s == null ? "" : ForumTextSanitizer.singleLine(s);
    }

    /** Cok satirli govde: satir sonlari korunur, art arda 3+ bos satir 2'ye iner. */
    public static String block(String s) {
        return s == null ? "" : ForumTextSanitizer.multiLine(s);
    }

    /** Kart onizlemesi: bosluklar sadelesir, en cok {@code max} karakter, kesilirse '…' eklenir. */
    public static String preview(String body, int max) {
        String flat = SPACES.matcher((body == null ? "" : body).replace('\n', ' ')).replaceAll(" ").strip();
        if (flat.length() <= max) {
            return flat;
        }
        int cut = max - 1;
        int sp = flat.lastIndexOf(' ', cut);
        if (sp > max / 2) {
            cut = sp;
        }
        return flat.substring(0, cut).stripTrailing() + "…";
    }
}
