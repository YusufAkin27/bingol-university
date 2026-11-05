package edu.bingol.backend.forum.poll;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** Anket secenegi. {@code voteCount} yalniz atomik UPDATE ile degisir (okuma-degistir-yaz yok). */
@Entity
@Table(name = "forum_poll_option")
@Getter
@Setter
public class ForumPollOption {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long pollId;

    @Column(nullable = false, length = 80)
    private String text;

    @Column(nullable = false)
    private int position;

    @Column(nullable = false)
    private int voteCount;

    public ForumPollOption() {}

    public ForumPollOption(Long pollId, String text, int position) {
        this.pollId = pollId;
        this.text = text;
        this.position = position;
    }
}
