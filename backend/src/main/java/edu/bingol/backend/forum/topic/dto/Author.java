package edu.bingol.backend.forum.topic.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Yazar gorunumu (konu ve yorum). Anonimde {@code userId/avatarUrl/department} null ve ad "Anonim #N" olur; baska
 * kullaniciya gercek kimlik HICBIR alandan sizmaz. {@code userId} bu nedenle yalniz anonim olmayan yazarda dolar.
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record Author(Long userId, String displayName, String avatarUrl, String department, boolean anonymous) {

    public static Author anonymous(String displayName) {
        return new Author(null, displayName, null, null, true);
    }
}
