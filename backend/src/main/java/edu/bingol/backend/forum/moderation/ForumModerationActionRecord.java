package edu.bingol.backend.forum.moderation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Forum moderasyon islem kaydi ({@code forum_moderation_action}). Silinmez (hesap silinse de actor_id satirda kalir:
 * kullanici satiri anonimlestirilir). {@code source}: MODERATOR (dogrudan eylem), REPORT (yonetici rapor karari),
 * REPORT_AUTO (rapor esigi asilinca otomatik gizleme).
 */
@Entity
@Table(name = "forum_moderation_action")
@Getter
@Setter
public class ForumModerationActionRecord {

    public static final String SOURCE_MODERATOR = "MODERATOR";
    public static final String SOURCE_REPORT = "REPORT";
    public static final String SOURCE_REPORT_AUTO = "REPORT_AUTO";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Yapan yonetici/moderator; Basic auth yoneticisi ve otomatik gizlemede null. */
    @Column(name = "actor_id")
    private Long actorId;

    @Column(name = "target_type", nullable = false, length = 16)
    private String targetType;

    @Column(name = "target_id", nullable = false)
    private Long targetId;

    /** Yorum islemlerinde ait oldugu konu; konu islemlerinde konunun kendisi. */
    @Column(name = "topic_id")
    private Long topicId;

    @Column(nullable = false, length = 16)
    private String action;

    @Column(length = 500)
    private String reason;

    @Column(nullable = false, length = 16)
    private String source = SOURCE_MODERATOR;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}
