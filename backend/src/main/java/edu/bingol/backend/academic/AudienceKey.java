package edu.bingol.backend.academic;

import java.util.Locale;
import java.util.Set;

/**
 * Hedef kitle (fakulte / bolum / sinif) eslemesinin TEK normalize kurali; Java ve SQL ayni sonucu verir (T-042).
 *
 * <p>Sorun: Java {@code "İ".toLowerCase(ROOT)} = "i" + birlestirici nokta (2 karakter), PostgreSQL {@code LOWER('İ')}
 * ise locale'e gore "i" ya da "İ" verir; ayrica {@code equalsIgnoreCase} 'İ' ile 'i' ni eslemez. Sonuc: "İşletme",
 * "İktisat", "İlahiyat" gibi buyuk İ ile baslayan adlar duyuru/anket hedef kitlesinde sessizce kayboluyordu.
 *
 * <p>Kural: bosluklar kirpilir; Turkce harfler ve i-ailesi ({@code İ I ı}) ASCII karsiliklarina indirgenir
 * ({@code ç ğ ö ş ü â î û} dahil, buyuk/kucuk), birlestirici nokta silinir, kalan harfler kucuk yapilir. SQL tarafi
 * {@code lower(translate(trim(kolon), FROM, TO))} ile birebir ayni tabloyu kullanir (locale bagimsiz: buyuk harfler
 * zaten translate ile ASCII'ye inmistir, lower yalniz A-Z isler).
 */
public final class AudienceKey {

    /** translate() kaynak karakterleri; sondaki U+0307 (birlestirici nokta) karsiligi olmadigi icin SILINIR. */
    static final String FROM = "İIıÇĞÖŞÜÂÎÛ"
            + "çğöşüâîû̇";
    static final String TO = "iiicgosuaiucgosuaiu";

    /** Sinif degerleri (duyuru / anket / sinav ile ayni kume; bkz. ExamService.GRADES). */
    public static final Set<String> GRADES = Set.of("PREP", "1", "2", "3", "4", "5", "6", "MASTER", "PHD");

    private AudienceKey() {}

    /** Java tarafi anahtar; bos/bosluk degeri null. */
    public static String of(String value) {
        if (value == null) {
            return null;
        }
        String v = value.strip();
        if (v.isEmpty()) {
            return null;
        }
        StringBuilder sb = new StringBuilder(v.length());
        for (int i = 0; i < v.length(); i++) {
            char c = v.charAt(i);
            int idx = FROM.indexOf(c);
            if (idx < 0) {
                sb.append(c);
            } else if (idx < TO.length()) {
                sb.append(TO.charAt(idx));
            } // birlestirici nokta: silinir
        }
        return sb.toString().toLowerCase(Locale.ROOT);
    }

    /** Iki deger ayni kitleyi mi gosteriyor (ikisi de null ise true; biri null ise false). */
    public static boolean same(String a, String b) {
        String x = of(a);
        String y = of(b);
        return x == null ? y == null : x.equals(y);
    }

    /** SQL ifadesi: {@code col} sutunu / ifadesi icin {@link #of} ile ayni sonuc. {@code col} guvenilir sabit olmalidir. */
    public static String sql(String col) {
        return "lower(translate(trim(" + col + "), '" + FROM + "', '" + TO + "'))";
    }

    /** JPQL ifadesi: from/to bagli parametre olarak (:tFrom, :tTo) verilir. */
    public static String jpql(String expr) {
        return "LOWER(FUNCTION('translate', TRIM(" + expr + "), :tFrom, :tTo))";
    }

    public static String fromChars() {
        return FROM;
    }

    public static String toChars() {
        return TO;
    }

    /** Sinif: kirpilir, BUYUK harfe cevrilir; kumede degilse {@code null} dondurmek yerine {@link IllegalArgumentException}. */
    public static String grade(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String v = raw.strip().toUpperCase(Locale.ROOT);
        if (!GRADES.contains(v)) {
            throw new IllegalArgumentException("grade");
        }
        return v;
    }
}
