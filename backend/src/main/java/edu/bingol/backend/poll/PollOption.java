package edu.bingol.backend.poll;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "poll_option")
@Getter
@Setter
public class PollOption {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long pollId;

    @Column(nullable = false)
    private short position;

    @Column(nullable = false, length = 100)
    private String text;

    /** Oy sayisi (RANKED'de 1. tercih sayisi). Yalniz atomik SQL ile degisir. */
    @Column(nullable = false, updatable = false)
    private int voteCount;

    /** RANKED icin Borda puani. */
    @Column(nullable = false, updatable = false)
    private int rankScore;

    public PollOption() {}

    public PollOption(Long pollId, int position, String text) {
        this.pollId = pollId;
        this.position = (short) position;
        this.text = text;
    }
}
