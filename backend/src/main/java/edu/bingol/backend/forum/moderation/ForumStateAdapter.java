package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.forum.notify.spi.ForumEventPublisher;
import edu.bingol.backend.forum.topic.spi.ForumTopicStateService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * {@link ForumStatePort} gercek uygulamasi: konu durumu A'nin {@link ForumTopicStateService}'ine, yorum durumu B'nin
 * yorum durum servisine, bildirim E'nin {@link ForumEventPublisher}'ina gider. Bildirim saglayicisi yoksa ya da hata
 * verirse islem geri alinmaz (yalniz log).
 */
@Component
public class ForumStateAdapter implements ForumStatePort {

    private static final Logger log = LoggerFactory.getLogger(ForumStateAdapter.class);

    private final ObjectProvider<ForumTopicStateService> topicProvider;
    private final ForumCommentStates comments;
    private final ObjectProvider<ForumEventPublisher> events;

    public ForumStateAdapter(ObjectProvider<ForumTopicStateService> topicProvider, ForumCommentStates comments,
                             ObjectProvider<ForumEventPublisher> events) {
        this.topicProvider = topicProvider;
        this.comments = comments;
        this.events = events;
    }

    private ForumTopicStateService topics() {
        return topicProvider.getObject();
    }

    @Override
    public void pinTopic(Long topicId) {
        topics().pin(topicId);
    }

    @Override
    public void unpinTopic(Long topicId) {
        topics().unpin(topicId);
    }

    @Override
    public void lockTopic(Long topicId) {
        topics().lock(topicId);
    }

    @Override
    public void unlockTopic(Long topicId) {
        topics().unlock(topicId);
    }

    @Override
    public void removeTopic(Long topicId, String reason) {
        topics().remove(topicId, reason);
    }

    @Override
    public void restoreTopic(Long topicId) {
        topics().restore(topicId);
    }

    @Override
    public void removeComment(Long commentId, String reason) {
        comments.remove(commentId, reason);
    }

    @Override
    public void restoreComment(Long commentId) {
        comments.restore(commentId);
    }

    @Override
    public void publishModeration(String targetType, Long targetId, Long topicId, String action, String reason) {
        try {
            ForumEventPublisher p = events.getIfAvailable();
            if (p == null) {
                return;
            }
            ForumEventPublisher.TargetType t = "COMMENT".equals(targetType)
                    ? ForumEventPublisher.TargetType.COMMENT : ForumEventPublisher.TargetType.TOPIC;
            p.moderationAction(t, targetId, action, reason);
        } catch (RuntimeException e) {
            log.warn("Forum moderasyon bildirimi gonderilemedi ({} #{}): {}", targetType, targetId, e.toString());
        }
    }
}
