package edu.bingol.backend.search;

import java.text.Normalizer;
import java.util.Locale;

/**
 * Turkce harf duyarsiz arama katlamasi: buyuk/kucuk harf ve Turkce karakterler (I, i, I-noktali, i-noktasiz, s, g, u, o, c;
 * ayrica a/i/u sapkali) ASCII karsiligina indirilir. Java tarafi (sorgu) ile SQL tarafi (sutun: translate + lower) AYNI
 * esleme tablosunu kullanir; {@link #SQL_FROM}/{@link #SQL_TO} degisirse V1230 indeksi ve UserRepository sorgusu da
 * guncellenmelidir.
 */
public final class TrFold {

    /** SQL translate() kaynak/hedef dizileri (uzunluklari esit; V1230 indeksiyle ayni). */
    public static final String SQL_FROM = "İIıŞşĞğÜüÖöÇçÂâÎîÛû";
    public static final String SQL_TO = "iiissgguuooccaaiiuu";

    private TrFold() {}

    /** Arama anahtari: NFC + Turkce katlama + kucuk harf; bastaki/sondaki ve ardisik bosluklar tek bosluga iner. */
    public static String fold(String s) {
        if (s == null) {
            return "";
        }
        String n = Normalizer.normalize(s, Normalizer.Form.NFC);
        StringBuilder b = new StringBuilder(n.length());
        boolean space = false;
        for (int i = 0; i < n.length(); i++) {
            char c = n.charAt(i);
            if (Character.isWhitespace(c) || Character.isSpaceChar(c)) {
                space = b.length() > 0;
                continue;
            }
            if (space) {
                b.append(' ');
                space = false;
            }
            int idx = SQL_FROM.indexOf(c);
            b.append(idx >= 0 ? SQL_TO.charAt(idx) : c);
        }
        return b.toString().toLowerCase(Locale.ROOT);
    }

    /** LIKE kacisi (\, %, _). */
    public static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
