package edu.bingol.backend.moderation.profanity;

import java.text.Normalizer;

/**
 * Metin sadelestirme yardimcilari (yalnizca filtre icin). Turkce: ç ğ ö ş ü sadelesir, ancak "ı" (noktasiz) "i"den
 * AYRI tutulur ki "sıkıntı" gibi masum sozcukler "sikinti" ile karismasin. Arapca: harekeler, tatweel ve alef/ya/ta
 * marbuta varyantlari sadelesir; Arapca-Hint rakamlari Latin'e cevrilir.
 */
final class ProfanityText {

    private ProfanityText() {}

    /** NFKD + kucuk harf + aksan/hareke atma + es goruntulu harf eslemesi. Rakam ve noktalama korunur. */
    static String fold(String s) {
        boolean ascii = true;
        for (int i = 0; i < s.length(); i++) {
            if (s.charAt(i) >= 128) {
                ascii = false;
                break;
            }
        }
        if (ascii) {
            return s.toLowerCase(java.util.Locale.ROOT); // hizli yol: ASCII'de NFKD gerekmez
        }
        String n = Normalizer.normalize(s, Normalizer.Form.NFKD);
        StringBuilder sb = new StringBuilder(n.length());
        for (int i = 0; i < n.length(); ) {
            int cp = n.codePointAt(i);
            i += Character.charCount(cp);
            int type = Character.getType(cp);
            if (type == Character.NON_SPACING_MARK || type == Character.ENCLOSING_MARK || type == Character.FORMAT
                    || cp == 0x640 /* tatweel */ || cp == 0x621 /* hemze tek basina */) {
                continue;
            }
            cp = map(Character.toLowerCase(cp)); // 'I' -> 'i', 'ı' kalir
            sb.appendCodePoint(cp);
        }
        return sb.toString();
    }

    private static int map(int c) {
        switch (c) {
            case 0x671: return 0x627;            // alef wasla
            case 0x649: return 0x64A;            // alef maksura -> ya
            case 0x629: return 0x647;            // ta marbuta -> ha
            case 0x6A9: return 0x643;            // Farsca kaf
            case 0x6CC: return 0x64A;            // Farsca ya
            // Cyrillic / Yunan es goruntulu harfler
            case 0x430: case 0x3B1: return 'a';
            case 0x435: case 0x3B5: return 'e';
            case 0x43E: case 0x3BF: return 'o';
            case 0x440: case 0x3C1: return 'p';
            case 0x441: return 'c';
            case 0x443: return 'y';
            case 0x445: return 'x';
            case 0x456: case 0x3B9: return 'i';
            case 0x43A: case 0x3BA: return 'k';
            case 0x43C: return 'm';
            case 0x442: case 0x3C4: return 't';
            case 0x43D: return 'h';
            case 0x432: return 'b';
            default:
        }
        if (c >= 0x660 && c <= 0x669) return '0' + (c - 0x660);   // Arapca-Hint rakamlar
        if (c >= 0x6F0 && c <= 0x6F9) return '0' + (c - 0x6F0);   // Dogu Arapca rakamlar
        return c;
    }

    /** Leet: yalnizca en az iki harf iceren sozcukte (salt sayilar bozulmasin). */
    static String leet(String f) {
        int letters = 0;
        boolean any = false;
        for (int i = 0; i < f.length(); i++) {
            char ch = f.charAt(i);
            if (Character.isLetter(ch)) letters++;
            else if (!Character.isWhitespace(ch) && (Character.isDigit(ch) || ch == '@' || ch == '$' || ch == '!')) any = true;
        }
        if (letters < 2 || !any) return f;
        StringBuilder sb = new StringBuilder(f.length());
        for (int i = 0; i < f.length(); i++) {
            char c = f.charAt(i);
            switch (c) {
                case '0': sb.append('o'); break;
                case '1': sb.append('i'); break;
                case '3': sb.append('e'); break;
                case '4': sb.append('a'); break;
                case '5': sb.append('s'); break;
                case '7': sb.append('t'); break;
                case '@': sb.append('a'); break;
                case '$': sb.append('s'); break;
                case '!':
                    boolean between = i > 0 && i + 1 < f.length() && Character.isLetter(f.charAt(i - 1))
                            && Character.isLetter(f.charAt(i + 1));
                    sb.append(between ? 'i' : c);
                    break;
                default: sb.append(c);
            }
        }
        return sb.toString();
    }

    /** 3+ ayni harf -> 2 ("orrrospu" -> "orrospu"). */
    static String v1(String s) {
        return collapse(s, 2);
    }

    /** Tum tekrarlar -> 1 ("orrospu" -> "orospu"). */
    static String v2(String s) {
        return collapse(s, 1);
    }

    private static String collapse(String s, int keep) {
        StringBuilder sb = null;
        int run = 0;
        char prev = 0;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (i > 0 && c == prev) {
                run++;
            } else {
                run = 1;
            }
            prev = c;
            boolean drop = run > keep && Character.isLetter(c);
            if (drop && sb == null) {
                sb = new StringBuilder(s.length()).append(s, 0, i);
            }
            if (!drop && sb != null) {
                sb.append(c);
            }
        }
        return sb == null ? s : sb.toString();
    }

    static boolean isArabic(int cp) {
        return (cp >= 0x600 && cp <= 0x6FF) || (cp >= 0x750 && cp <= 0x77F);
    }

    static boolean hasArabic(String s) {
        for (int i = 0; i < s.length(); i++) {
            if (isArabic(s.charAt(i))) return true;
        }
        return false;
    }
}
