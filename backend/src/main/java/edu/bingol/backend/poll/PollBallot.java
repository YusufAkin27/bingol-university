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

/** Secmen kaydi: (anket, kullanici) tekil. Neye oy verildigini TUTMAZ (o poll_vote'ta, anonimlestirilebilir). */
@Entity
@Table(name = "poll_ballot", uniqueConstraints = @UniqueConstraint(name = "pol330_ballot_uq", columnNames = {"pollId", "userId"}))
@Getter
@Setter
public class PollBallot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long pollId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public PollBallot() {}

    public PollBallot(Long pollId, Long userId) {
        this.pollId = pollId;
        this.userId = userId;
    }
}
