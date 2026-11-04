package edu.bingol.backend.post.comment;

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
 * Gonderi/reel yorumu (V1230). En cok iki seviye: ust duzey yorum (parentId null) ve yanitlar (parentId = ust duzey
 * yorum). Yanita verilen yanit ust duzey yoruma yassilanir; replyToId asil yanitlanan yorumu tutar. Silme yumusaktir
 * (deletedAt; metin temizlenir); yonetici/rapor gizlemesi hiddenAt. Sayaclar atomik SQL ile guncellenir.
 */
@Entity
@Table(name = "post_comment")
@org.hibernate.annotations.DynamicUpdate
@Getter
@Setter
public class PostComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long postId;

    private Long parentId;

    private Long replyToId;

    @Column(nullable = false)
    private Long authorId;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    @Column(nullable = false)
    private int likeCount;

    @Column(nullable = false)
    private int replyCount;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant deletedAt;

    private Long deletedBy;

    private Instant hiddenAt;

    @Column(length = 300)
    private String hiddenReason;

    public boolean isVisible() {
        return deletedAt == null && hiddenAt == null;
    }

    public boolean isReply() {
        return parentId != null;
    }
}
