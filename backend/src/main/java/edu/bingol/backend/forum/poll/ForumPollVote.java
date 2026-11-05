package edu.bingol.backend.forum.poll;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Oy: PK(poll_id, user_id) kisi basina tek oyu veritabani seviyesinde garanti eder. Satir kimlik tasir (tek-oy kurali
 * icin) ancak hicbir uc oy verenleri listelemez. Yazma {@link ForumPollVoteRepository} yerel INSERT/UPDATE'leriyle
 * yapilir (save/merge sessizce uzerine yazardi).
 */
@Entity
@Table(name = "forum_poll_vote")
@IdClass(ForumPollVoteId.class)
@Getter
@Setter
public class ForumPollVote {

    @Id
    private Long pollId;

    @Id
    private Long userId;

    @Column(nullable = false)
    private Long optionId;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public ForumPollVote() {}
}
