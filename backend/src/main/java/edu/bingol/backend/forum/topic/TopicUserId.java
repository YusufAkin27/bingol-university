package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** (topic_id, user_id) bilesik anahtari: forum_topic_like, forum_topic_follow ve forum_anon_alias ortak kullanir. */
@Embeddable
@Getter
@NoArgsConstructor
public class TopicUserId implements Serializable {

    @Column(name = "topic_id", nullable = false)
    private Long topicId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    public TopicUserId(Long topicId, Long userId) {
        this.topicId = topicId;
        this.userId = userId;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof TopicUserId k && Objects.equals(topicId, k.topicId) && Objects.equals(userId, k.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(topicId, userId);
    }
}
