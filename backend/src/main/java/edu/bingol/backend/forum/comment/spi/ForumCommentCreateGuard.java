package edu.bingol.backend.forum.comment.spi;

/**
 * Yorum olusturmadan ONCE calisan istege bagli denetim noktasi (D: tekrarlayan ayni metin / spam siniri gibi).
 * Birden fazla bean kaydedilebilir; ihlalde ApiException firlatir. Temizlenmis (normalize edilmis) govde verilir.
 */
public interface ForumCommentCreateGuard {

    void beforeCreate(Long userId, Long topicId, String body);
}
