package edu.bingol.backend.forum.poll;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Konu anketi (konu basina en cok bir tane). Bitis zamani okuma aninda hesaplanir; zamanlayici yok. */
@Entity
@Table(name = "forum_poll", uniqueConstraints = @UniqueConstraint(name = "fc14_poll_topic_uq", columnNames = "topicId"))
@Getter
@Setter
public class ForumPoll {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long topicId;

    @Column(length = 200)
    private String question;

    private Instant endsAt;

    @Column(nullable = false)
    private boolean allowChangeVote;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public ForumPoll() {}

    /** Bitis zamani gectiyse kapali. */
    public boolean isClosedAt(Instant now) {
        return endsAt != null && !endsAt.isAfter(now);
    }
}
