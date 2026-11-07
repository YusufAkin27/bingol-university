package edu.bingol.backend.forum.search;

import edu.bingol.backend.common.ApiException;
import org.springframework.http.HttpStatus;

/** Forum arama siralamasi (beyaz liste; SQL'e yalniz bu sabitlerden gecer). */
public enum ForumSearchSort {
    RELEVANCE, NEWEST, POPULAR;

    /** Bos/null = RELEVANCE; taninmayan deger 400 FORUM_SEARCH_BAD_SORT. */
    public static ForumSearchSort parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return RELEVANCE;
        }
        try {
            return valueOf(raw.trim().toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_SEARCH_BAD_SORT", "Geçersiz sıralama.");
        }
    }
}
