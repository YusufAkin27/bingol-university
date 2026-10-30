package edu.bingol.backend.search;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Tek bir arama sonucu. targetId ilgili turun kendi id'sidir (mobil, type'a gore detay ucuna gider).
 * snippet kisa, duz metin ozet (HTML icermez). Opsiyonel (yoksa JSON'a hic yazilmaz): COMMUNITY icin memberCount, category ve
 * istek sahibinin uyeligi myStatus (ACTIVE | PENDING | NONE); POSTS icin likeCount; EVENT icin startsAt/endsAt (ISO, saat araligi).
 */
public record SearchHit(SearchType type, Long targetId, String title, String snippet, String imageUrl, String date,
                        @JsonInclude(JsonInclude.Include.NON_NULL) Long memberCount,
                        @JsonInclude(JsonInclude.Include.NON_NULL) String category,
                        @JsonInclude(JsonInclude.Include.NON_NULL) String myStatus,
                        @JsonInclude(JsonInclude.Include.NON_NULL) Long likeCount,
                        @JsonInclude(JsonInclude.Include.NON_NULL) String startsAt,
                        @JsonInclude(JsonInclude.Include.NON_NULL) String endsAt) {

    public SearchHit(SearchType type, Long targetId, String title, String snippet, String imageUrl, String date) {
        this(type, targetId, title, snippet, imageUrl, date, null, null, null, null, null, null);
    }

    public SearchHit(SearchType type, Long targetId, String title, String snippet, String imageUrl, String date,
                     Long memberCount, String category, String myStatus, Long likeCount) {
        this(type, targetId, title, snippet, imageUrl, date, memberCount, category, myStatus, likeCount, null, null);
    }
}
