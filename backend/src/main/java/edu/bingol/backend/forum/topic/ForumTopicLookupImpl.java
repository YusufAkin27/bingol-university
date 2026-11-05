package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.topic.spi.ForumTopicLookup;
import edu.bingol.backend.forum.topic.spi.TopicRef;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** {@link ForumTopicLookup} uygulamasi: gorunurluk kurali {@link ForumTopicRepository#VISIBLE} ile tek yerde. */
@Service
public class ForumTopicLookupImpl implements ForumTopicLookup {

    private final ForumTopicRepository topics;
    private final ForumViewerFilter filter;

    public ForumTopicLookupImpl(ForumTopicRepository topics, ForumViewerFilter filter) {
        this.topics = topics;
        this.filter = filter;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<TopicRef> visibleTopic(Long topicId, Long viewerId) {
        if (topicId == null || viewerId == null) {
            return Optional.empty();
        }
        return topics.findVisible(topicId, viewerId, filter.hiddenFrom(viewerId)).map(ForumTopicLookupImpl::ref);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<TopicRef> topic(Long topicId) {
        if (topicId == null) {
            return Optional.empty();
        }
        return topics.findByIdAndDeletedAtIsNull(topicId).map(ForumTopicLookupImpl::ref);
    }

    static TopicRef ref(ForumTopic t) {
        return new TopicRef(t.getId(), t.getUserId(), t.isAnonymous(), t.isLocked(), t.getCategoryId(),
                t.isRemoved() ? TopicRef.Status.REMOVED : TopicRef.Status.ACTIVE);
    }
}
