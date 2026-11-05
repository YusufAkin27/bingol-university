package edu.bingol.backend.forum.topic;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.topic.spi.ForumTopicStateService;
import edu.bingol.backend.forum.topic.spi.TopicRef;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Konunun moderasyon durum alanlari (yetki + denetim kaydi cagirandadir, D). Hepsi idempotenttir. */
@Service
public class ForumTopicStateServiceImpl implements ForumTopicStateService {

    private final ForumTopicRepository topics;

    public ForumTopicStateServiceImpl(ForumTopicRepository topics) {
        this.topics = topics;
    }

    @Override
    @Transactional
    public TopicRef pin(Long topicId) {
        ForumTopic t = load(topicId);
        if (t.getPinnedAt() == null) {
            t.setPinnedAt(Instant.now());
        }
        return ForumTopicLookupImpl.ref(t);
    }

    @Override
    @Transactional
    public TopicRef unpin(Long topicId) {
        ForumTopic t = load(topicId);
        t.setPinnedAt(null);
        return ForumTopicLookupImpl.ref(t);
    }

    @Override
    @Transactional
    public TopicRef lock(Long topicId) {
        ForumTopic t = load(topicId);
        if (t.getLockedAt() == null) {
            t.setLockedAt(Instant.now());
        }
        return ForumTopicLookupImpl.ref(t);
    }

    @Override
    @Transactional
    public TopicRef unlock(Long topicId) {
        ForumTopic t = load(topicId);
        t.setLockedAt(null);
        return ForumTopicLookupImpl.ref(t);
    }

    @Override
    @Transactional
    public TopicRef remove(Long topicId, String reason) {
        ForumTopic t = load(topicId);
        t.setStatus(ForumTopic.REMOVED);
        String r = reason == null ? null : reason.strip();
        t.setRemovedReason(r == null || r.isEmpty() ? null : r.substring(0, Math.min(r.length(), 300)));
        return ForumTopicLookupImpl.ref(t);
    }

    @Override
    @Transactional
    public TopicRef restore(Long topicId) {
        ForumTopic t = load(topicId);
        t.setStatus(ForumTopic.ACTIVE);
        t.setRemovedReason(null);
        return ForumTopicLookupImpl.ref(t);
    }

    private ForumTopic load(Long topicId) {
        return topics.findByIdAndDeletedAtIsNull(topicId).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "FORUM_TOPIC_NOT_FOUND", "Konu bulunamadı."));
    }
}
