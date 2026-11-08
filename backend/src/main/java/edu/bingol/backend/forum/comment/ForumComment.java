package edu.bingol.backend.forum.comment;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Forum yorumu (V1410). Sinirsiz derinlikte agac: parentCommentId dogrudan ust yorum, rootCommentId zincirin kokundeki
 * ust duzey yorum (ust duzeyde null). Entity yalnizca EKLEME ve sema icindir; guncellemeler ForumCommentCounters/
 * ForumCommentStore uzerinden atomik SQL ile yapilir (okuma-degistir-yaz yok). Baska varliklara JPA iliskisi kurulmaz.
 */
@Entity
@Table(name = "forum_comment",
        uniqueConstraints = @UniqueConstraint(name = "fb14_comment_idem_uq", columnNames = {"user_id", "idempotency_key"}),
        indexes = {
            @Index(name = "fb14_comment_topic_top_idx", columnList = "topic_id,id"),
            @Index(name = "fb14_comment_parent_idx", columnList = "parent_comment_id,id")})
@Getter
@Setter
public class ForumComment {

    public static final String ACTIVE = "ACTIVE";
    public static final String REMOVED = "REMOVED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "topic_id", nullable = false)
    private Long topicId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "parent_comment_id")
    private Long parentCommentId;

    @Column(name = "root_comment_id")
    private Long rootCommentId;

    @Column(nullable = false)
    private int depth;

    @Column(nullable = false, length = 4000)
    private String body;

    @Column(nullable = false)
    private boolean anonymous;

    @Column(name = "like_count", nullable = false)
    private int likeCount;

    /** Gorunen begeni eki (V1700); arayuze like_count + like_boost gider. */
    @Column(name = "like_boost", nullable = false)
    private int likeBoost;

    @Column(name = "reply_count", nullable = false)
    private int replyCount;

    @Column(nullable = false, length = 16)
    private String status = ACTIVE;

    @Column(name = "removed_reason", length = 500)
    private String removedReason;

    @Column(name = "removed_at")
    private Instant removedAt;

    @Column(name = "idempotency_key", length = 100)
    private String idempotencyKey;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(name = "edited_at")
    private Instant editedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;
}
