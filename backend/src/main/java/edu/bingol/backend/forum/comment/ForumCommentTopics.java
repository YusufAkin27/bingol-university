package edu.bingol.backend.forum.comment;

import edu.bingol.backend.forum.notify.spi.ForumEventPublisher;
import edu.bingol.backend.forum.topic.ForumBookmark;
import edu.bingol.backend.forum.topic.ForumBookmarkService;
import edu.bingol.backend.forum.topic.spi.ForumAuthorResolver;
import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.forum.topic.spi.ForumTopicLookup;
import edu.bingol.backend.forum.topic.spi.TopicRef;
import java.util.Optional;
import java.util.Set;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * Yorum modulunun A (konu), D (sessize alma) ve E (bildirim) alanlarina TEK bagi: yalniz bu sinif onlarin
 * arayuzlerini bilir. Sessize alma ve olay yayinlayici istege baglidir (ObjectProvider; yoksa atlanir).
 */
@Component
class ForumCommentTopics {

    /** Yorum icin gereken konu bilgisi. authorId GERCEK sahip (anonim olsa da): API'ye verilmez. */
    record TopicInfo(long id, long authorId, boolean anonymous, boolean locked) {}

    private final ForumTopicLookup topics;
    private final ForumAuthorResolver authors;
    private final ObjectProvider<ForumMuteLookup> mutes;
    private final ObjectProvider<ForumEventPublisher> events;
    private final ForumBookmarkService bookmarks;

    ForumCommentTopics(ForumTopicLookup topics, ForumAuthorResolver authors, ObjectProvider<ForumMuteLookup> mutes,
                       ObjectProvider<ForumEventPublisher> events, ForumBookmarkService bookmarks) {
        this.topics = topics;
        this.authors = authors;
        this.mutes = mutes;
        this.events = events;
        this.bookmarks = bookmarks;
    }

    /** Konu bakana gorunurse (silinmemis, kaldirilmamis, engel/sessize alma yok). */
    Optional<TopicInfo> visible(Long topicId, Long viewerId) {
        return topics.visibleTopic(topicId, viewerId).map(ForumCommentTopics::info);
    }

    private static TopicInfo info(TopicRef t) {
        return new TopicInfo(t.id(), t.authorId(), t.anonymous(), t.locked());
    }

    /**
     * (konu, kullanici) icin kararli anonim takma adi ONCEDEN tahsis ettirir: A'nin yazar cozumleyicisi eksik numarayi
     * olusturur, boylece numara ilk anonim yorumun yazildigi siraya gore kalici olur.
     */
    void ensureAlias(Long topicId, Long userId) {
        authors.resolve(userId, new ForumAuthorResolver.Key(topicId, userId, true));
    }

    /** Bakanin sessize aldigi kullanicilar (D yoksa bos). */
    Set<Long> mutedBy(Long viewerId) {
        ForumMuteLookup m = mutes.getIfAvailable();
        return m == null ? Set.of() : m.mutedBy(viewerId);
    }

    void commentCreated(Long commentId, Long actorId) {
        ForumEventPublisher p = events.getIfAvailable();
        if (p != null) {
            p.commentCreated(commentId, actorId);
        }
    }

    void commentLiked(Long commentId, Long actorId) {
        ForumEventPublisher p = events.getIfAvailable();
        if (p != null) {
            p.commentLiked(commentId, actorId);
        }
    }

    /** Yorumu kaydet / kaydi kaldir (A'nin ForumBookmarkService'i; hedef COMMENT, idempotent). */
    void setSaved(Long userId, Long commentId, boolean saved) {
        if (saved) {
            bookmarks.save(userId, ForumBookmark.COMMENT, commentId);
        } else {
            bookmarks.unsave(userId, ForumBookmark.COMMENT, commentId);
        }
    }
}
