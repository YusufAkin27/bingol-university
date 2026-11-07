package edu.bingol.backend.post.mention;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Gonderide etiketlenen kisi (post_mention, V1310). Etiketleyen her zaman gonderinin yazaridir. */
@Entity
@Table(name = "post_mention")
@Getter
@Setter
@NoArgsConstructor
public class PostMention {

    @EmbeddedId
    private PostMentionId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public PostMention(Long postId, Long userId) {
        this.id = new PostMentionId(postId, userId);
    }
}
