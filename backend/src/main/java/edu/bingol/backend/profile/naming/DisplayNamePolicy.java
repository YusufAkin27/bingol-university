package edu.bingol.backend.profile.naming;

import edu.bingol.backend.common.ApiException;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.http.HttpStatus;

/**
 * Gorunen ad dogrulama/normallestirme: kontrol, bidi, sifir genislikli ve gorunmez karakterler reddedilir;
 * bosluklar tek bosluga indirilir; uzunluk kod noktasi ile olculur; en fazla 2 emoji; ayni kelimede
 * Latin+Kiril/Yunan karisimi (homoglif) reddedilir; yonetici/destek taklidi yazim hilelerine karsi
 * "iskelet" uzerinden kontrol edilir (yoneticiler muaf).
 */
public final class DisplayNamePolicy {

    public static final int MIN_LEN = 2;
    public static final int MAX_LEN = 80;
    static final int MAX_EMOJI = 2;
    static final int MAX_COMBINING_RUN = 2;

    /** Tek basina ya da kelime olarak yasak (iskelet bicimiyle: kucuk harf, aksansiz, latin). */
    static final Set<String> RESERVED_WORDS = Set.of("admin", "administrator", "yonetici", "yonetim", "moderator",
            "destek", "support", "sistem", "system", "rektor", "rektorluk", "official", "resmi", "bukampus");

    /** Bitisik iskelette gecmesi yasak ifadeler (bosluk/noktalama hileleri icin). */
    static final List<String> RESERVED_PHRASES = List.of("bukampus", "bingoluniversitesi", "destekekibi",
            "supportteam", "yoneticiekibi", "adminteam", "bingolunivers");

    private static final Set<Integer> INVISIBLE_LETTERS = Set.of(0x115F, 0x1160, 0x17B4, 0x17B5, 0x2800, 0x3164,
            0xFFA0, 0x180E);

    private DisplayNamePolicy() {}

    public static String normalize(String raw, boolean exemptFromReserved) {
        if (raw == null) {
            throw invalid();
        }
        String s = Normalizer.normalize(raw, Normalizer.Form.NFC);
        StringBuilder sb = new StringBuilder();
        int emoji = 0;
        int combiningRun = 0;
        int letters = 0;
        boolean lastSpace = true; // basta bosluk biriktirme
        for (int i = 0; i < s.length(); ) {
            int cp = s.codePointAt(i);
            i += Character.charCount(cp);
            int type = Character.getType(cp);
            if (cp == 0xFE0E || cp == 0xFE0F) {
                continue; // emoji varyasyon secicisi: sessizce at
            }
            if (type == Character.SPACE_SEPARATOR || cp == ' ') {
                if (!lastSpace) {
                    sb.append(' ');
                }
                lastSpace = true;
                combiningRun = 0;
                continue;
            }
            if (Character.isISOControl(cp) || type == Character.FORMAT || type == Character.PRIVATE_USE
                    || type == Character.SURROGATE || type == Character.UNASSIGNED
                    || type == Character.LINE_SEPARATOR || type == Character.PARAGRAPH_SEPARATOR
                    || INVISIBLE_LETTERS.contains(cp)) {
                throw invalid();
            }
            boolean mark = type == Character.NON_SPACING_MARK || type == Character.COMBINING_SPACING_MARK
                    || type == Character.ENCLOSING_MARK;
            if (mark) {
                if (lastSpace || ++combiningRun > MAX_COMBINING_RUN) {
                    throw invalid();
                }
            } else {
                combiningRun = 0;
            }
            if (isEmoji(cp, type)) {
                if (++emoji > MAX_EMOJI) {
                    throw invalid();
                }
            } else if (Character.isLetter(cp)) {
                letters++;
            } else if (!(mark || Character.isDigit(cp) || ".'’-_,()".indexOf(cp) >= 0)) {
                throw invalid(); // @, /, <, >, :, vb. ve diger semboller
            }
            sb.appendCodePoint(cp);
            lastSpace = false;
        }
        String out = sb.toString().strip();
        int len = out.codePointCount(0, out.length());
        if (len < MIN_LEN || len > MAX_LEN || letters < 2) {
            throw invalid();
        }
        checkMixedScript(out);
        if (!exemptFromReserved && isReserved(out)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RESERVED_DISPLAY_NAME",
                    "Bu ad kullanılamaz (yönetici/destek adına benzer).");
        }
        return out;
    }

    private static boolean isEmoji(int cp, int type) {
        return (cp >= 0x1F000 && cp <= 0x1FAFF) || (cp >= 0x2190 && type == Character.OTHER_SYMBOL);
    }

    private static void checkMixedScript(String s) {
        for (String word : s.split(" ")) {
            boolean latin = false;
            boolean other = false;
            for (int i = 0; i < word.length(); ) {
                int cp = word.codePointAt(i);
                i += Character.charCount(cp);
                if (!Character.isLetter(cp)) {
                    continue;
                }
                Character.UnicodeScript sc = Character.UnicodeScript.of(cp);
                if (sc == Character.UnicodeScript.LATIN) {
                    latin = true;
                } else if (sc == Character.UnicodeScript.CYRILLIC || sc == Character.UnicodeScript.GREEK) {
                    other = true;
                }
            }
            if (latin && other) {
                throw invalid();
            }
        }
    }

    /** Taklit denetimi icin: kucuk harf, aksansiz, benzer karakterler latin harfe indirgenmis, harf/rakam disi atilmis. */
    static String skeleton(String s) {
        String d = Normalizer.normalize(s.toLowerCase(Locale.ROOT), Normalizer.Form.NFKD);
        StringBuilder sb = new StringBuilder();
        d.codePoints().forEach(cp -> {
            if (Character.getType(cp) == Character.NON_SPACING_MARK) {
                return;
            }
            sb.appendCodePoint(fold(cp));
        });
        return sb.toString();
    }

    private static int fold(int cp) {
        return switch (cp) {
            case 'ı' -> 'i';
            case 'а' -> 'a'; // Kiril
            case 'е' -> 'e';
            case 'о', 'ο' -> 'o';
            case 'р', 'ρ' -> 'p';
            case 'с' -> 'c';
            case 'х' -> 'x';
            case 'і', 'ι' -> 'i';
            case 'у' -> 'y';
            case 'к' -> 'k';
            case 'м' -> 'm';
            case 'т' -> 't';
            case 'н' -> 'h';
            case 'α' -> 'a';
            case 'ε' -> 'e';
            case '0' -> 'o';
            case '1', '!', '|' -> 'i';
            case '3' -> 'e';
            case '4', '@' -> 'a';
            case '5', '$' -> 's';
            case '7' -> 't';
            default -> cp;
        };
    }

    static boolean isReserved(String name) {
        String sk = skeleton(name);
        List<String> tokens = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        StringBuilder compact = new StringBuilder();
        for (int i = 0; i < sk.length(); ) {
            int cp = sk.codePointAt(i);
            i += Character.charCount(cp);
            if (Character.isLetterOrDigit(cp)) {
                cur.appendCodePoint(cp);
                compact.appendCodePoint(cp);
            } else if (cur.length() > 0) {
                tokens.add(cur.toString());
                cur.setLength(0);
            }
        }
        if (cur.length() > 0) {
            tokens.add(cur.toString());
        }
        Set<String> words = new HashSet<>(tokens);
        for (String r : RESERVED_WORDS) {
            if (words.contains(r) || compact.toString().equals(r)) {
                return true;
            }
        }
        String c = compact.toString();
        return RESERVED_PHRASES.stream().anyMatch(c::contains);
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DISPLAY_NAME", "Geçersiz görünen ad.");
    }
}
