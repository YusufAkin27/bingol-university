package edu.bingol.backend.forum.comment.spi;

import java.util.Optional;

/** Yorum kaydini (gorunurluk SURUMU olmadan) okuyan ince SPI: D/E modulleri (rapor, bildirim, profil) kullanir. */
public interface ForumCommentLookup {

    /** Silinmis/kaldirilmis olsa da kayit varsa doner; bakan bazli gorunurluk karari cagirana aittir. */
    Optional<CommentRef> find(Long commentId);

    /**
     * @param authorId     GERCEK yazar kimligi (anonim olsa da): yalnizca sunucu ici karar icin, API'ye verilmez
     * @param removed      moderator kaldirdi
     * @param deleted      sahibi sildi
     * @param parentAuthorId dogrudan ust yorumun yazari (yoksa null)
     */
    record CommentRef(Long id, Long topicId, Long authorId, Long parentCommentId, Long parentAuthorId, int depth,
                      boolean anonymous, boolean removed, boolean deleted) {

        /** Normal yanitlarda gorunebilir mi (canli). */
        public boolean live() {
            return !removed && !deleted;
        }
    }
}
