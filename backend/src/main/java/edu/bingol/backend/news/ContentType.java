package edu.bingol.backend.news;

public enum ContentType {
    DUYURU(0), HABER(1), ETKINLIK(2);

    private final int siteCode;

    ContentType(int siteCode) {
        this.siteCode = siteCode;
    }

    /** Buyuk/kucuk harf ve Turkce i/I farkina toleransli; bos ise null, taninmazsa IllegalArgumentException. */
    public static ContentType parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String key = raw.trim().toUpperCase(java.util.Locale.ROOT).replace('İ', 'I');
        return valueOf(key);
    }

    /** bingol.edu.tr HaberDuyuruEtkinlik.aspx?tip= degeri */
    public int siteCode() {
        return siteCode;
    }
}
