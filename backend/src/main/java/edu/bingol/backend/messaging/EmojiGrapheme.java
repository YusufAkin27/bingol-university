package edu.bingol.backend.messaging;

/**
 * Tepki icin "tek bir emoji" dogrulayicisi (Java 17'de {@code \p{Emoji}} yok: kod noktasi araliklari elle).
 * Kabul: basit emoji, ten rengi (U+1F3FB-1F3FF), ZWJ dizileri (aile, meslek...), bayrak (bolgesel gosterge cifti),
 * etiketli bayrak (Ingiltere...), keycap (1 + FE0F + 20E3), degisim secici FE0F. Duz harf/rakam/noktalama/bosluk/
 * kontrol/URL ve birden fazla emoji REDDEDILIR. Boyut: en cok 16 UTF-16 birimi / 10 kod noktasi
 * (`message_reaction.emoji` VARCHAR(16)).
 */
final class EmojiGrapheme {

    static final int MAX_UNITS = 16;
    static final int MAX_CODE_POINTS = 10;

    private static final int ZWJ = 0x200D;
    private static final int VS16 = 0xFE0F;
    private static final int KEYCAP = 0x20E3;
    private static final int BLACK_FLAG = 0x1F3F4;

    private EmojiGrapheme() {}

    static boolean isSingleEmoji(String s) {
        if (s == null || s.isEmpty() || s.length() > MAX_UNITS) {
            return false;
        }
        int[] cps = s.codePoints().toArray();
        if (cps.length == 0 || cps.length > MAX_CODE_POINTS) {
            return false;
        }
        // keycap: [0-9#*] FE0F? 20E3
        if (isKeycapBase(cps[0])) {
            int i = 1;
            if (i < cps.length && cps[i] == VS16) {
                i++;
            }
            return i == cps.length - 1 && cps[i] == KEYCAP;
        }
        // bayrak: iki bolgesel gosterge
        if (isRegionalIndicator(cps[0])) {
            return cps.length == 2 && isRegionalIndicator(cps[1]);
        }
        // etiketli bayrak: 1F3F4 + etiket harfleri (E0020-E007E)+ E007F
        if (cps[0] == BLACK_FLAG && cps.length > 2 && isTag(cps[1])) {
            for (int i = 1; i < cps.length - 1; i++) {
                if (!isTag(cps[i]) || cps[i] == 0xE007F) {
                    return false;
                }
            }
            return cps[cps.length - 1] == 0xE007F;
        }
        // eleman (ZWJ eleman)*; eleman = taban (FE0F | ten rengi)*
        int i = 0;
        while (true) {
            if (i >= cps.length || !isBase(cps[i])) {
                return false;
            }
            i++;
            while (i < cps.length && (cps[i] == VS16 || isSkinTone(cps[i]))) {
                i++;
            }
            if (i == cps.length) {
                return true;
            }
            if (cps[i] != ZWJ) {
                return false; // ikinci bir emoji ya da yabanci karakter
            }
            i++;
        }
    }

    private static boolean isKeycapBase(int cp) {
        return (cp >= '0' && cp <= '9') || cp == '#' || cp == '*';
    }

    private static boolean isRegionalIndicator(int cp) {
        return cp >= 0x1F1E6 && cp <= 0x1F1FF;
    }

    private static boolean isSkinTone(int cp) {
        return cp >= 0x1F3FB && cp <= 0x1F3FF;
    }

    private static boolean isTag(int cp) {
        return cp >= 0xE0020 && cp <= 0xE007F;
    }

    /** Emoji tabani: resimli semboller + belirli yazi simgeleri (telif, tescil, TM, !!, ...). Rakam/harf/noktalama DEGIL. */
    private static boolean isBase(int cp) {
        if (isSkinTone(cp) || isRegionalIndicator(cp)) {
            return false;
        }
        return (cp >= 0x1F300 && cp <= 0x1F64F)   // Misc Symbols & Pictographs, Emoticons
                || (cp >= 0x1F680 && cp <= 0x1F6FF) // Transport
                || (cp >= 0x1F900 && cp <= 0x1F9FF) // Supplemental Symbols
                || (cp >= 0x1FA70 && cp <= 0x1FAFF) // Extended-A / Symbols and Pictographs Ext-A
                || (cp >= 0x1F000 && cp <= 0x1F0FF) // kart/mahjong/domino
                || (cp >= 0x1F170 && cp <= 0x1F251) // kapali alfanumerikler
                || (cp >= 0x2600 && cp <= 0x26FF)   // Misc Symbols
                || (cp >= 0x2700 && cp <= 0x27BF)   // Dingbats
                || (cp >= 0x2B05 && cp <= 0x2B07) || cp == 0x2B1B || cp == 0x2B1C || cp == 0x2B50 || cp == 0x2B55
                || cp == 0x2934 || cp == 0x2935
                || (cp >= 0x2194 && cp <= 0x2199) || cp == 0x21A9 || cp == 0x21AA
                || cp == 0x231A || cp == 0x231B || cp == 0x2328 || cp == 0x23CF
                || (cp >= 0x23E9 && cp <= 0x23F3) || (cp >= 0x23F8 && cp <= 0x23FA)
                || cp == 0x24C2 || cp == 0x25AA || cp == 0x25AB || cp == 0x25B6 || cp == 0x25C0
                || (cp >= 0x25FB && cp <= 0x25FE)
                || cp == 0x203C || cp == 0x2049 || cp == 0x2122 || cp == 0x2139
                || cp == 0xA9 || cp == 0xAE || cp == 0x3030 || cp == 0x303D || cp == 0x3297 || cp == 0x3299;
    }
}
