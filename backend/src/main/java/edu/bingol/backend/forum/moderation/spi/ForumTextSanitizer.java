package edu.bingol.backend.forum.moderation.spi;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Forum metin temizleyici (saf fonksiyonlar; bean degil, her modul dogrudan cagirir). Hedef: veritabanina/istemciye
 * giden metin DUZ METIN olsun, gorunmez/yaniltici karakter ve HTML kalintisi tasimasin.
 *
 * <ul>
 *   <li>NFC normalizasyonu; kontrol karakterleri (NUL dahil; satir sonu ve sekme haric) silinir, CRLF/CR -> LF,
 *       sekme -> bosluk.</li>
 *   <li>Sifir genislik/gorunmez karakterler (ZWSP, WORD JOINER, BOM, soft hyphen, Mongolian vowel separator) ve
 *       iki yonlu METIN DEGISTIRME karakterleri (LRE/RLE/PDF/LRO/RLO ve izolatlar: "Trojan source" tarzi
 *       yanilticilik) silinir. ZWJ/ZWNJ emoji ve Arap/Fars yazisi icin gerekir: yalniz iki yani da ASCII harf/rakam
 *       olan (gizli bolme/hile) durumda silinir. LRM/RLM korunur.</li>
 *   <li>HTML: {@code <script>/<style>} bloklari icerigiyle, yorumlar ve {@code <etiket ...>} kalibi (olay
 *       oznitelikleri dahil) silinir; tekrarli geciste ic ice hile ("&lt;scr&lt;script&gt;ipt&gt;") temizlenir.
 *       Tek basina {@code <} / {@code >} ("a &lt; b", "&lt;3") korunur. {@code javascript:} gibi baglanti metni DUZ METIN
 *       kalir (istemci metni baglantiya cevirmez; sunucu hicbir yerde HTML uretmez).</li>
 *   <li>Bosluk: satir ici ardisik bosluklar tek bosluk, satir sonu bosluklari silinir, ardisik bos satirlar en
 *       cok bir bos satira iner, bas/son kirpilir. Tek satirlik alanlarda ({@link #singleLine}) tum satir sonlari
 *       bosluga cevrilir.</li>
 * </ul>
 *
 * Bos kalan sonuc "" doner; cagiran bunu {@code FORUM_CONTENT_EMPTY} gibi kendi kodu ile reddeder.
 */
public final class ForumTextSanitizer {

    private ForumTextSanitizer() {}

    private static final int MAX_PASSES = 6;

    private static final Pattern BLOCK_TAGS = Pattern.compile(
            "<(script|style|iframe|object|embed|noscript|template)\\b[^>]*>.*?</\\s*\\1\\s*>",
            Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
    /** Kapanmamis script/style: acilistan sona kadar sil (tarayici da oyle yorumlar). */
    private static final Pattern OPEN_BLOCK = Pattern.compile(
            "<(script|style|iframe|object|embed|noscript|template)\\b.*", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
    private static final Pattern COMMENT = Pattern.compile("<!--.*?(-->|$)", Pattern.DOTALL);
    private static final Pattern DECLARATION = Pattern.compile("<[!?][^<>]*>");
    private static final Pattern TAG = Pattern.compile("</?[a-zA-Z][^<>]*>");
    private static final Pattern INLINE_WS = Pattern.compile("[ \\u00A0\\u2000-\\u200A\\u202F\\u205F\\u3000]+");
    private static final Pattern MANY_BLANK_LINES = Pattern.compile("\\n{3,}");

    /** Cok satirli govde/aciklama/yorum. */
    public static String multiLine(String s) {
        return clean(s, true);
    }

    /** Tek satirli alan (baslik, anket secenegi, gerekce). */
    public static String singleLine(String s) {
        return clean(s, false);
    }

    /** Sonucun bos olup olmadigi (null da bos). */
    public static boolean isBlank(String cleaned) {
        return cleaned == null || cleaned.isBlank();
    }

    /**
     * Karsilastirma anahtari (spam/tekrar): temizlenmis metin, NFKC, kucuk harf, harf ve rakam disi her sey atilir.
     * "Merhaba!!", " merhaba " ve gorunmez karakterli varyantlar ayni anahtari verir.
     */
    public static String compareKey(String s) {
        if (s == null) {
            return "";
        }
        String t = Normalizer.normalize(multiLine(s), Normalizer.Form.NFKC).toLowerCase(Locale.ROOT);
        StringBuilder sb = new StringBuilder(t.length());
        t.codePoints().forEach(cp -> {
            if (Character.isLetterOrDigit(cp)) {
                sb.appendCodePoint(cp);
            }
        });
        return sb.toString();
    }

    static String clean(String s, boolean multiline) {
        if (s == null) {
            return null;
        }
        String t = Normalizer.normalize(s, Normalizer.Form.NFC);
        t = t.replace((char) 0x2028, (char) 10).replace((char) 0x2029, (char) 10);
        // once gorunmezler (etiketin icine gizlenen NUL/ZWSP filtreyi atlatmasin), sonra HTML, sonra yine gorunmezler
        t = stripInvisible(t);
        t = stripHtml(t);
        t = stripInvisible(t);
        t = t.replace("\r\n", "\n").replace('\r', '\n');
        if (!multiline) {
            t = t.replace('\n', ' ');
        }
        // sekme ve benzeri bosluklar tek bosluk
        t = t.replace('\t', ' ');
        t = INLINE_WS.matcher(t).replaceAll(" ");
        if (multiline) {
            StringBuilder sb = new StringBuilder(t.length());
            for (String line : t.split("\n", -1)) {
                if (sb.length() > 0) {
                    sb.append('\n');
                }
                sb.append(line.strip());
            }
            t = MANY_BLANK_LINES.matcher(sb).replaceAll("\n\n");
        }
        return t.strip();
    }

    private static String stripHtml(String in) {
        String t = in;
        for (int i = 0; i < MAX_PASSES; i++) {
            String before = t;
            t = BLOCK_TAGS.matcher(t).replaceAll("");
            t = OPEN_BLOCK.matcher(t).replaceAll("");
            t = COMMENT.matcher(t).replaceAll("");
            t = DECLARATION.matcher(t).replaceAll("");
            t = TAG.matcher(t).replaceAll("");
            if (t.equals(before)) {
                break;
            }
        }
        return t;
    }

    private static String stripInvisible(String t) {
        StringBuilder sb = new StringBuilder(t.length());
        int[] cps = t.codePoints().toArray();
        for (int i = 0; i < cps.length; i++) {
            int cp = cps[i];
            if (cp == '\n' || cp == '\r' || cp == '\t') {
                sb.appendCodePoint(cp);
                continue;
            }
            if (Character.isISOControl(cp) || cp == 0xFFFE || cp == 0xFFFF
                    || (cp >= 0xD800 && cp <= 0xDFFF) /* eslesmemis vekil */) {
                continue;
            }
            switch (cp) {
                case 0x200B, 0x2060, 0xFEFF, 0x180E, 0x00AD, 0x034F -> {
                    continue;
                }
                default -> { }
            }
            // iki yonlu metin degistirme / izolat karakterleri (LRM 200E ve RLM 200F korunur)
            if ((cp >= 0x202A && cp <= 0x202E) || (cp >= 0x2066 && cp <= 0x2069) || (cp >= 0x2061 && cp <= 0x2064)) {
                continue;
            }
            if (cp == 0x200C || cp == 0x200D) {
                boolean prevAscii = i > 0 && isAsciiAlnum(cps[i - 1]);
                boolean nextAscii = i + 1 < cps.length && isAsciiAlnum(cps[i + 1]);
                if (prevAscii && nextAscii) {
                    continue;
                }
            }
            // etiket karakterleri (U+E0000..E007F, gorunmez ASCII tasima) ve varyasyon secicisiz tek basina bicim karakterleri
            if (cp >= 0xE0000 && cp <= 0xE007F) {
                continue;
            }
            sb.appendCodePoint(cp);
        }
        return sb.toString();
    }

    private static boolean isAsciiAlnum(int cp) {
        return (cp >= '0' && cp <= '9') || (cp >= 'a' && cp <= 'z') || (cp >= 'A' && cp <= 'Z');
    }
}
