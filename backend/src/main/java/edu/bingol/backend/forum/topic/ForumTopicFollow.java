package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Konu takibi + bildirim tercihi. follow=true: takip ediyor. follow=false + notify=false: takip etmeyenin
 * (ornegin konu sahibinin) "bildirimleri kapat" tercihi.
 */
@Entity
@Table(name = "forum_topic_follow")
@Getter
@Setter
@NoArgsConstructor
public class ForumTopicFollow {

    @EmbeddedId
    private TopicUserId id;

    @Column(nullable = false)
    private boolean notify = true;

    @Column(nullable = false)
    private boolean follow = true;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public ForumTopicFollow(Long topicId, Long userId) {
        this.id = new TopicUserId(topicId, userId);
    }
}
