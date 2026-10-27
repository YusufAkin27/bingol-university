package edu.bingol.backend.poll;

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

/** Tek secenek oyu. userId hesap silinince null olur (anonimlestirme). Hicbir API/yonetici ekrani userId'yi gostermez. */
@Entity
@Table(name = "poll_vote", uniqueConstraints = @UniqueConstraint(name = "pol330_vote_uq", columnNames = {"pollId", "userId", "optionId"}))
@Getter
@Setter
public class PollVote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long pollId;

    @Column(nullable = false)
    private Long optionId;

    private Long userId;

    /** Tercih sirasi (1 = en cok); SINGLE/MULTI/RATING'de 1. */
    @Column(name = "choice_rank", nullable = false)
    private short choiceRank = 1;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public PollVote() {}

    public PollVote(Long pollId, Long optionId, Long userId, int choiceRank) {
        this.pollId = pollId;
        this.optionId = optionId;
        this.userId = userId;
        this.choiceRank = (short) choiceRank;
    }
}
