package edu.bingol.backend.forum.comment;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Bir kullanicinin bir yorumu begenisi (forum_comment_like; PK = (comment_id, user_id) ikinci begeniyi engeller). */
@Entity
@Table(name = "forum_comment_like")
@Getter
@Setter
@NoArgsConstructor
public class ForumCommentLike {

    @EmbeddedId
    private ForumCommentLikeId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public ForumCommentLike(Long commentId, Long userId) {
        this.id = new ForumCommentLikeId(commentId, userId);
    }
}
