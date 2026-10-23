package edu.bingol.backend.news;

public enum ContentType {
    DUYURU(0), HABER(1), ETKINLIK(2);

    private final int siteCode;

    ContentType(int siteCode) {
        this.siteCode = siteCode;
    }

    /** bingol.edu.tr HaberDuyuruEtkinlik.aspx?tip= degeri */
    public int siteCode() {
        return siteCode;
    }
}
