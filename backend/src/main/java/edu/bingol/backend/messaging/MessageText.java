package edu.bingol.backend.messaging;

import java.text.Normalizer;

/**
 * Mesaj metni temizleyici. Metin DUZ METIN olarak saklanir (HTML etiketleri silinmez, "a < b & c" aynen kalir);
 * asil XSS savunmasi istemcinin metni kacirarak/`Text` ile gostermesidir. Burada yalnizca gorunmez/yanıltici
 * karakterler ve gecersiz Unicode temizlenir.
 */
public final class MessageText {

    private MessageText() {}

    /** NFC, satir sonlari \n, kontrol/bidi/sifir genislikli karakterler ve yetim vekil karakterler atilir, kirpilir. */
    public static String clean(String raw) {
        if (raw == null) {
            return "";
        }
        String s = Normalizer.normalize(raw, Normalizer.Form.NFC).replace("\r\n", "\n").replace('\r', '\n');
        StringBuilder sb = new StringBuilder(s.length());
        s.codePoints().filter(cp -> !dropped(cp)).forEach(sb::appendCodePoint);
        return sb.toString().replaceAll("\n{3,}", "\n\n").strip();
    }

    private static boolean dropped(int cp) {
        if (cp == '\n' || cp == '\t') {
            return false;
        }
        return cp < 0x20 || (cp >= 0x7F && cp <= 0x9F)          // kontrol karakterleri
                || (cp >= 0xD800 && cp <= 0xDFFF)                // yetim vekil (UTF-8'e yazilamaz)
                || (cp >= 0x202A && cp <= 0x202E)                // bidi gömme/override
                || (cp >= 0x2066 && cp <= 0x2069)                // bidi izolasyon
                || cp == 0x200B || cp == 0x2060 || cp == 0xFEFF  // sifir genislikli bosluk / word joiner / BOM
                || cp == 0x200E || cp == 0x200F || cp == 0x061C; // yon isaretleri
    }
}
