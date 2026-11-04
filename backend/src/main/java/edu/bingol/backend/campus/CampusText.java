package edu.bingol.backend.campus;

import java.text.Normalizer;
import java.util.List;
import java.util.Locale;

/** Arama anahtari uretimi: Turkce duyarsiz sadelestirme ve LIKE kacisi. */
public final class CampusText {

    private CampusText() {}

    /**
     * Kucuk harf + Turkce karakter sadelestirme (i/ı/İ -> i, ş -> s, ğ -> g, ü -> u, ö -> o, ç -> c) + bilesik isaret
     * temizligi + bosluk birlestirme. Ornek: "Mühendislik Fakültesi" -> "muhendislik fakultesi". "mü" -> "mu".
     * Locale.ROOT ile kucultme (Turkce yerelinde I -> ı olurdu); once harfler elle eslenir.
     */
    public static String normalize(String s) {
        if (s == null) {
            return "";
        }
        StringBuilder b = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case 'İ', 'I', 'ı' -> b.append('i');
                case 'Ş', 'ş' -> b.append('s');
                case 'Ğ', 'ğ' -> b.append('g');
                case 'Ü', 'ü' -> b.append('u');
                case 'Ö', 'ö' -> b.append('o');
                case 'Ç', 'ç' -> b.append('c');
                default -> b.append(c);
            }
        }
        String lower = b.toString().toLowerCase(Locale.ROOT);
        String nfd = Normalizer.normalize(lower, Normalizer.Form.NFD);
        StringBuilder out = new StringBuilder(nfd.length());
        boolean space = true; // bas bosluklari at
        for (int i = 0; i < nfd.length(); i++) {
            char c = nfd.charAt(i);
            if (Character.getType(c) == Character.NON_SPACING_MARK) {
                continue;
            }
            if (Character.isWhitespace(c) || Character.isISOControl(c)) {
                if (!space) {
                    out.append(' ');
                    space = true;
                }
            } else {
                out.append(c);
                space = false;
            }
        }
        int n = out.length();
        return n > 0 && out.charAt(n - 1) == ' ' ? out.substring(0, n - 1) : out.toString();
    }

    /** Birim listesinin arama anahtari: sadelestirilmis adlarin bosluklu birlesimi. */
    public static String unitsKey(List<String> units) {
        if (units == null || units.isEmpty()) {
            return "";
        }
        return String.join(" | ", units.stream().map(CampusText::normalize).filter(x -> !x.isEmpty()).toList());
    }

    /** LIKE ozel karakterlerini kacirir (kacis karakteri {@code \}). */
    public static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
