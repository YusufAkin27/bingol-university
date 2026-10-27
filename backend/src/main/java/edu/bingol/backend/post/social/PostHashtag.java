package edu.bingol.backend.post.social;

import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Gonderi - etiket baglantisi. id: a = post_id, b = hashtag_id. */
@Entity
@Table(name = "post_hashtag")
@Getter
@Setter
@NoArgsConstructor
public class PostHashtag {

    @EmbeddedId
    @AttributeOverrides({@AttributeOverride(name = "a", column = @Column(name = "post_id")),
            @AttributeOverride(name = "b", column = @Column(name = "hashtag_id"))})
    private PairId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public PostHashtag(Long postId, Long hashtagId) {
        this.id = new PairId(postId, hashtagId);
    }
}
