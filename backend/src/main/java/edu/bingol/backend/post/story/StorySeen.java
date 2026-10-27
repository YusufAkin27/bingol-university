package edu.bingol.backend.post.story;

import edu.bingol.backend.post.social.PairId;
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

/** Hikayeyi goruntuleyen (tablo story_view). id: a = story_id, b = viewer_id. */
@Entity
@Table(name = "story_view")
@Getter
@Setter
@NoArgsConstructor
public class StorySeen {

    @EmbeddedId
    @AttributeOverrides({@AttributeOverride(name = "a", column = @Column(name = "story_id")),
            @AttributeOverride(name = "b", column = @Column(name = "viewer_id"))})
    private PairId id;

    @Column(name = "viewed_at", nullable = false)
    private Instant viewedAt = Instant.now();

    public StorySeen(Long storyId, Long viewerId) {
        this.id = new PairId(storyId, viewerId);
    }
}
