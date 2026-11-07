package edu.bingol.backend.forum.category;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Kategori aramasi icin metin katlama: Turkce karakterlere (c/g/i/o/s/u, buyuk/kucuk I/i/I-noktali/i-noktasiz)
 * ve Arapca harekelere duyarsiz, kucuk harf. Veritabaninda unaccent eklentisi YOKTUR; kategori listesi kucuk
 * (en cok 200) oldugundan eslesme Java'da yapilir.
 */
final class ForumCategorySearchText {

    static final int MAX_Q = 60;
    private static final Pattern MARKS = Pattern.compile("\\p{M}+");
    private static final Pattern SPACES = Pattern.compile("[\\s&/,.\\-_]+");

    private ForumCategorySearchText() {}

    /** Katlanmis metin: noktasiz i -> i, aksanlar atilir, Arapca tatwil/harekeler atilir, kucuk harf. */
    static String fold(String s) {
        if (s == null) {
            return "";
        }
        String t = s.replace('ı', 'i').replace('İ', 'I').replace('ـ', ' ');
        t = Normalizer.normalize(t, Normalizer.Form.NFD);
        t = MARKS.matcher(t).replaceAll("");
        t = t.toLowerCase(Locale.ROOT);
        // ARABIC YEH/TEH MARBUTA: yaygin yazim farklari ayni sayilir
        return t.replace('ى', 'ي').replace('ة', 'ه');
    }

    /** Sorguyu katlanmis sozcuklere boler (en cok 6; fazlasi yok sayilir). Bos ise bos liste. */
    static List<String> tokens(String q) {
        List<String> out = new ArrayList<>();
        if (q == null) {
            return out;
        }
        String f = fold(q.length() > MAX_Q ? q.substring(0, MAX_Q) : q);
        for (String part : SPACES.split(f.strip())) {
            if (!part.isBlank() && out.size() < 6) {
                out.add(part);
            }
        }
        return out;
    }

    /** Her sozcuk samanlikta geciyorsa eslesir (VE). Bos sozcuk listesi herkesle eslesir. */
    static boolean matches(List<String> tokens, String foldedHaystack) {
        for (String tk : tokens) {
            if (!foldedHaystack.contains(tk)) {
                return false;
            }
        }
        return true;
    }
}
