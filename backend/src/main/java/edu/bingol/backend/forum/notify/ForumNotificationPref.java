package edu.bingol.backend.forum.notify;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Forum bildirim tercihi (V1440). Satir yoksa hepsi acik. {@code moderation} her zaman true (kapatilamaz). */
@Entity
@Table(name = "forum_notification_pref")
@Getter
@Setter
public class ForumNotificationPref {

    @Id
    private Long userId;

    @Column(nullable = false)
    private boolean allEnabled = true;
    @Column(nullable = false)
    private boolean topicComments = true;
    @Column(nullable = false)
    private boolean commentReplies = true;
    @Column(nullable = false)
    private boolean likes = true;
    @Column(nullable = false)
    private boolean followedTopics = true;
    @Column(nullable = false)
    private boolean moderation = true;
    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public static ForumNotificationPref defaults(Long userId) {
        ForumNotificationPref p = new ForumNotificationPref();
        p.setUserId(userId);
        return p;
    }
}
