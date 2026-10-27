package edu.bingol.backend.post.admin;

import edu.bingol.backend.post.PostDeletedEvent;
import edu.bingol.backend.post.comment.PostCommentService;
import edu.bingol.backend.post.like.PostLikeService;
import edu.bingol.backend.post.media.PostMediaService;
import java.util.List;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silmede (KVKK) Kesfet verisi: once medya, begeniler, yorumlar (baskasinin gonderisindeki yorum "silindi"
 * olur), sonra kullanicinin gonderileri yumusak silinir ve her biri icin PostDeletedEvent yayinlanir (dosyalar
 * tutma suresi sonunda temizlenir). AccountDataPurger.purge tarafindan, diger kayitlardan once cagrilir.
 */
@Component
public class PostAccountPurger {

    private final PostMediaService media;
    private final PostLikeService likes;
    private final PostCommentService comments;
    private final JdbcTemplate jdbc;
    private final ApplicationEventPublisher events;

    public PostAccountPurger(PostMediaService media, PostLikeService likes, PostCommentService comments,
                             JdbcTemplate jdbc, ApplicationEventPublisher events) {
        this.media = media;
        this.likes = likes;
        this.comments = comments;
        this.jdbc = jdbc;
        this.events = events;
    }

    /** Sosyal veri (kaydet, takip, hikaye); yoksa atlanir. */
    private edu.bingol.backend.post.social.SocialAccountPurger social;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setSocial(edu.bingol.backend.post.social.SocialAccountPurger social) {
        this.social = social;
    }

    public void purge(Long userId) {
        List<Long> postIds = jdbc.queryForList("SELECT id FROM post WHERE author_id = ? AND deleted_at IS NULL", Long.class, userId);
        // Olay icin medya kimlikleri, medya temizligi calismadan ONCE okunur
        List<PostDeletedEvent> evts = postIds.stream().map(id -> new PostDeletedEvent(id,
                jdbc.queryForList("SELECT id FROM post_media WHERE post_id = ?", Long.class, id))).toList();
        media.purgeUser(userId);
        likes.purgeUser(userId);
        comments.purgeUser(userId);
        jdbc.update("UPDATE post SET deleted_at = CURRENT_TIMESTAMP, deleted_by = ? WHERE author_id = ? AND deleted_at IS NULL",
                userId, userId);
        evts.forEach(events::publishEvent);
        if (social != null) {
            social.purge(userId);
        }
    }
}
