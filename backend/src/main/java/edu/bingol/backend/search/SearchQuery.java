package edu.bingol.backend.search;

import edu.bingol.backend.common.ApiException;
import org.springframework.http.HttpStatus;

/** Arama girdisinin ortak temizligi ve LIKE kacisi (haber arama + SearchService kullanir). */
public final class SearchQuery {

    public static final int MIN_LEN = 2;
    public static final int MAX_LEN = 100;

    private SearchQuery() {}

    /** Bosluklari sadelestirir; cok kisaysa 400 firlatir, cok uzunsa keser. */
    public static String normalize(String raw) {
        return normalize(raw, MIN_LEN);
    }

    /** Alt sinir cagirana gore: herkese acik haber aramasi 3 ister (2 karakter trigram indeksini kullanamaz). */
    public static String normalize(String raw, int minLen) {
        String q = raw == null ? "" : raw.trim().replaceAll("\\s+", " ");
        if (q.codePointCount(0, q.length()) < minLen) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "Arama en az " + minLen + " karakter olmalı.");
        }
        return q.length() <= MAX_LEN ? q : q.substring(0, MAX_LEN);
    }

    /** ILIKE deseni: %, _ ve \ kacirilir (PostgreSQL varsayilan kacis karakteri ters bolu). */
    public static String likePattern(String q) {
        String esc = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
        return "%" + esc + "%";
    }
}
