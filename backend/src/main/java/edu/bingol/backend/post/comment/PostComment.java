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

/** Genel gonderi yorumu / ic ice yanit (depth 0..3). Sayaclar servis tarafindan ayni islemde tutulur. */
@Entity
@Table(name = "post_comment")
@Getter
@Setter
public class PostComment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long postId;

    private Long parentId;

    /** Kok yorumun id'si (kok icin kendi id'si). */
    private Long rootId;

    @Column(nullable = false)
    private short depth;

    @Column(nullable = false)
    private Long authorId;

    private Long replyToUserId;

    @Column(columnDefinition = "TEXT")
    private String body;

    /** Dogrudan alt yanit sayisi (silinmemis veya kendi yaniti olan). */
    @Column(nullable = false)
    private int replyCount;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant editedAt;

    private Instant deletedAt;

    private Long deletedBy;

    private Instant hiddenAt;

    /** Listede gorunur mu: gizli degil ve (silinmemis ya da yaniti olan "silindi" kaydi). */
    public boolean isListed() {
        return hiddenAt == null && (deletedAt == null || replyCount > 0);
    }
}
