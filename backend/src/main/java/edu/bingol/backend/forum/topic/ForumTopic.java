package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Forum konusu. Sayaclar (comment/like/bookmark) yalniz atomik SQL ile guncellenir (okuma-degistir-yaz YOK);
 * entity uzerinden sayac yazilmaz. Yumusak silme: deletedAt. Gercek yazar kimligi (userId) istemciye ASLA verilmez.
 */
@Entity
@Table(name = "forum_topic", indexes = @Index(name = "fa14_topic_idem_uq", columnList = "user_id, idem_key", unique = true))
@org.hibernate.annotations.DynamicUpdate
@Getter
@Setter
public class ForumTopic {

    public static final String ACTIVE = "ACTIVE";
    public static final String REMOVED = "REMOVED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long categoryId;

    @Column(nullable = false, length = 150)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    @Column(nullable = false)
    private boolean anonymous;

    @Column(nullable = false)
    private int commentCount;

    @Column(nullable = false)
    private int likeCount;

    /** Gorunen begeni eki (V1700): arayuze likeCount + likeBoost gider; siralama gercek sayiyla calisir. */
    @Column(nullable = false, columnDefinition = "INT DEFAULT 0")
    private int likeBoost;

    @Column(nullable = false)
    private int bookmarkCount;

    @Column(nullable = false)
    private short imageCount;

    private Instant pinnedAt;

    private Instant lockedAt;

    @Column(nullable = false, length = 10)
    private String status = ACTIVE;

    @Column(length = 300)
    private String removedReason;

    @Column(length = 100)
    private String idemKey;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    private Instant editedAt;

    private Instant deletedAt;

    @Column(nullable = false)
    private Instant lastActivityAt = Instant.now();

    public boolean isLocked() {
        return lockedAt != null;
    }

    public boolean isRemoved() {
        return REMOVED.equals(status);
    }
}
