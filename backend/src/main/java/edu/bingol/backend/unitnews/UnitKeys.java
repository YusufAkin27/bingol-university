package edu.bingol.backend.unitnews;

import edu.bingol.backend.academic.AudienceKey;
import java.util.regex.Pattern;

/** Bolum adi eslesme anahtari: profildeki bolum ile alt sitedeki bolum/program ayni kurala indirgenir. */
public final class UnitKeys {

    private static final Pattern SUFFIX = Pattern.compile("\\s+(bolumu|programi|bolum|program)$");
    private static final Pattern DASH = Pattern.compile("\\s*[-\\u2013\\u2014]\\s*");
    private static final Pattern SPACES = Pattern.compile("\\s+");
    private static final Pattern PAREN = Pattern.compile("\\s*\\([^)]*\\)\\s*");

    private UnitKeys() {}

    /**
     * {@link AudienceKey} + tire bosluklari birlestirilir, parantezli ekler ("(Ikinci Ogretim)") ve sondaki
     * "Bolumu/Programi" atilir. Bos girdi null.
     */
    public static String deptKey(String name) {
        String k = AudienceKey.of(name);
        if (k == null) {
            return null;
        }
        k = PAREN.matcher(k).replaceAll(" ").strip();
        k = DASH.matcher(k).replaceAll("-");
        k = SPACES.matcher(k).replaceAll(" ").strip();
        k = SUFFIX.matcher(k).replaceFirst("");
        return k.isEmpty() ? null : (k.length() > 200 ? k.substring(0, 200) : k);
    }
}
