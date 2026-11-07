package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Konu begenisi (PK = (topic_id, user_id): ayni kisi ayni konuyu iki kez begenemez). */
@Entity
@Table(name = "forum_topic_like")
@Getter
@Setter
@NoArgsConstructor
public class ForumTopicLike {

    @EmbeddedId
    private TopicUserId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public ForumTopicLike(Long topicId, Long userId) {
        this.id = new TopicUserId(topicId, userId);
    }
}
