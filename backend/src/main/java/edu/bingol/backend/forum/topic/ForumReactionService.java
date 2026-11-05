package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.notify.spi.ForumEventPublisher;
import edu.bingol.backend.forum.topic.ForumTopicDtos.FollowState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.LikeState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.NotificationsState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.SaveState;
import edu.bingol.backend.forum.topic.spi.ForumTopicFollowLookup;
import java.util.List;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Konu begenisi, kaydetme, takip ve bildirim tercihi. Hepsi idempotenttir. Begeni: satir + atomik sayac ayni islemde;
 * es zamanli cift PUT'ta benzersiz kisit ihlali ya da kilit hatasi islem DISINDA yakalanir (Hibernate oturumu ihlalden
 * sonra kullanilamaz) ve "zaten begenilmis" sayilir. Kendi konusunu begenmek olay uretmez.
 */
@Service
public class ForumReactionService implements ForumTopicFollowLookup {

    private static final Logger log = LoggerFactory.getLogger(ForumReactionService.class);
    /** Es zamanli yazma cakismasinda (benzersiz kisit / kilit) yeniden deneme sayisi. */
    private static final int MAX_TRIES = 6;

    private final ForumTopicService topicService;
    private final ForumTopicRepository topics;
    private final ForumTopicFollowRepository follows;
    private final ForumBookmarkService bookmarks;
    private final JdbcTemplate jdbc;
    private final ObjectProvider<ForumEventPublisher> events;
    private final TransactionTemplate tx;

    public ForumReactionService(ForumTopicService topicService, ForumTopicRepository topics,
                                ForumTopicFollowRepository follows, ForumBookmarkService bookmarks, JdbcTemplate jdbc,
                                ObjectProvider<ForumEventPublisher> events, PlatformTransactionManager tm) {
        this.topicService = topicService;
        this.topics = topics;
        this.follows = follows;
        this.bookmarks = bookmarks;
        this.jdbc = jdbc;
        this.events = events;
        this.tx = new TransactionTemplate(tm);
    }

    // ------------------------------------------------------------------ begeni

    public LikeState like(Long userId, Long topicId) {
        ForumTopic t = topicService.visibleOrThrow(topicId, userId);
        boolean added = false;
        for (int attempt = 0; attempt < MAX_TRIES; attempt++) {
            try {
                added = Boolean.TRUE.equals(tx.execute(st -> insertLike(userId, topicId)));
                break;
            } catch (DataIntegrityViolationException | ConcurrencyFailureException e) {
                if (likeExists(userId, topicId)) {
                    added = false; // satiri baska istek ekledi, sayac onda artti
                    break;
                }
                if (attempt == MAX_TRIES - 1) {
                    throw e;
                }
            }
        }
        if (added && !t.getUserId().equals(userId)) {
            ForumEventPublisher p = events.getIfAvailable();
            if (p != null) {
                try {
                    p.topicLiked(topicId, userId);
                } catch (RuntimeException e) {
                    log.warn("Forum begeni olayi atlandi (konu {}): {}", topicId, e.toString());
                }
            }
        }
        return new LikeState(true, topics.likeCountOf(topicId).orElse(0));
    }

    private boolean insertLike(Long userId, Long topicId) {
        int n = jdbc.update("INSERT INTO forum_topic_like (topic_id, user_id, created_at) "
                + "SELECT CAST(? AS BIGINT), CAST(? AS BIGINT), CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM forum_topic_like WHERE topic_id = ? AND user_id = ?)",
                topicId, userId, topicId, userId);
        if (n == 0) {
            return false;
        }
        topics.addLikes(topicId, 1);
        return true;
    }

    private boolean likeExists(Long userId, Long topicId) {
        Integer c = jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic_like WHERE topic_id = ? AND user_id = ?",
                Integer.class, topicId, userId);
        return c != null && c > 0;
    }

    public LikeState unlike(Long userId, Long topicId) {
        topicService.visibleOrThrow(topicId, userId);
        tx.executeWithoutResult(st -> {
            int n = jdbc.update("DELETE FROM forum_topic_like WHERE topic_id = ? AND user_id = ?", topicId, userId);
            if (n > 0) {
                topics.addLikes(topicId, -1);
            }
        });
        return new LikeState(false, topics.likeCountOf(topicId).orElse(0));
    }

    // ------------------------------------------------------------------ kaydet

    public SaveState save(Long userId, Long topicId) {
        topicService.visibleOrThrow(topicId, userId);
        for (int attempt = 0; attempt < MAX_TRIES; attempt++) {
            try {
                bookmarks.save(userId, ForumBookmark.TOPIC, topicId);
                return new SaveState(true);
            } catch (DataIntegrityViolationException | ConcurrencyFailureException e) {
                if (!bookmarks.savedAmong(userId, ForumBookmark.TOPIC, List.of(topicId)).isEmpty()) {
                    return new SaveState(true);
                }
                if (attempt == MAX_TRIES - 1) {
                    throw e;
                }
            }
        }
        return new SaveState(true);
    }

    public SaveState unsave(Long userId, Long topicId) {
        topicService.visibleOrThrow(topicId, userId);
        bookmarks.unsave(userId, ForumBookmark.TOPIC, topicId);
        return new SaveState(false);
    }

    // ------------------------------------------------------------------ takip / bildirim

    public FollowState follow(Long userId, Long topicId) {
        topicService.visibleOrThrow(topicId, userId);
        retry(() -> tx.executeWithoutResult(st -> {
            ForumTopicFollow f = follows.find(topicId, userId).orElse(null);
            if (f == null) {
                f = new ForumTopicFollow(topicId, userId);
            }
            f.setFollow(true);
            follows.saveAndFlush(f);
        }), userId, topicId);
        return new FollowState(true);
    }

    public FollowState unfollow(Long userId, Long topicId) {
        topicService.visibleOrThrow(topicId, userId);
        tx.executeWithoutResult(st -> follows.find(topicId, userId).ifPresent(f -> {
            if (f.isNotify()) {
                follows.delete(f); // tercih varsayilan: satira gerek yok
            } else {
                f.setFollow(false); // "bildirimleri kapat" tercihi korunur
                follows.save(f);
            }
        }));
        return new FollowState(false);
    }

    /** Takip etmeyen kisi icin de gecerli: kapatma tercihi satir olarak tutulur (follow=false, notify=false). */
    public NotificationsState setNotifications(Long userId, Long topicId, boolean enabled) {
        topicService.visibleOrThrow(topicId, userId);
        retry(() -> tx.executeWithoutResult(st -> {
            ForumTopicFollow f = follows.find(topicId, userId).orElse(null);
            if (f == null) {
                if (enabled) {
                    return; // varsayilan zaten acik
                }
                f = new ForumTopicFollow(topicId, userId);
                f.setFollow(false);
            }
            f.setNotify(enabled);
            if (!f.isFollow() && f.isNotify()) {
                follows.delete(f);
            } else {
                follows.saveAndFlush(f);
            }
        }), userId, topicId);
        return new NotificationsState(enabled);
    }

    private void retry(Runnable r, Long userId, Long topicId) {
        for (int attempt = 0; attempt < MAX_TRIES; attempt++) {
            try {
                r.run();
                return;
            } catch (DataIntegrityViolationException | ConcurrencyFailureException e) {
                if (attempt == MAX_TRIES - 1) {
                    throw e;
                }
            }
        }
    }

    // ------------------------------------------------------------------ ForumTopicFollowLookup

    @Override
    public Set<Long> notifyFollowers(Long topicId, int limit) {
        return Set.copyOf(follows.notifyFollowers(topicId, PageRequest.of(0, Math.max(1, Math.min(limit, 5000)))));
    }

    @Override
    public boolean notificationsEnabled(Long topicId, Long userId) {
        return follows.find(topicId, userId).map(ForumTopicFollow::isNotify).orElse(true);
    }

    /** KVKK: kullanicinin begenileri (+ sayaclar), takipleri silinir. */
    public void purgeUser(Long userId) {
        tx.executeWithoutResult(st -> {
            jdbc.update("UPDATE forum_topic SET like_count = like_count - 1 WHERE like_count > 0 AND id IN "
                    + "(SELECT topic_id FROM forum_topic_like WHERE user_id = ?)", userId);
            jdbc.update("DELETE FROM forum_topic_like WHERE user_id = ?", userId);
            jdbc.update("DELETE FROM forum_topic_follow WHERE user_id = ?", userId);
        });
    }
}
