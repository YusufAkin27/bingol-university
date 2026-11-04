package edu.bingol.backend.campus;

import java.util.List;
import java.util.Locale;

/**
 * Kampus yeri kategorileri: sabit beyaz liste (yeni kategori = bu enum + {@code campus.cat.<anahtar>} cevirisi + DB
 * CHECK kisiti). Siralama haritadaki sekme sirasidir. {@code icon} mobil ikon anahtari, {@code color} hex renktir.
 */
public enum CampusCategory {

    FACULTY("faculty", "school", "#1E5AA8"),
    INSTITUTE("institute", "science", "#4A7FC1"),
    SCHOOL("school", "account_balance", "#2F6DB0"),
    VOCATIONAL("vocational", "construction", "#8A6BC2"),
    DINING("dining", "restaurant", "#E07B39"),
    LIBRARY("library", "local_library", "#7B4FB8"),
    SPORTS("sports", "sports_soccer", "#2E9B5B"),
    HEALTH("health", "local_hospital", "#D64545"),
    ADMIN("admin", "business", "#5B6B7C"),
    SERVICE("service", "miscellaneous_services", "#6B8E23"),
    DORM("dorm", "hotel", "#A0714F"),
    GATE("gate", "local_parking", "#3C8DAD"),
    SOCIAL("social", "park", "#C2398A");

    private final String key;
    private final String icon;
    private final String color;

    CampusCategory(String key, String icon, String color) {
        this.key = key;
        this.icon = icon;
        this.color = color;
    }

    public String key() {
        return key;
    }

    public String icon() {
        return icon;
    }

    public String color() {
        return color;
    }

    /** Ceviri anahtari (campus.properties). */
    public String labelKey() {
        return "campus.cat." + key;
    }

    /** Kesin anahtar eslesmesi (buyuk/kucuk harf duyarsiz); bilinmeyen/bos ise null. */
    public static CampusCategory parse(String value) {
        if (value == null) {
            return null;
        }
        String v = value.trim().toLowerCase(Locale.ROOT);
        for (CampusCategory c : values()) {
            if (c.key.equals(v)) {
                return c;
            }
        }
        return null;
    }

    public static List<CampusCategory> ordered() {
        return List.of(values());
    }
}
