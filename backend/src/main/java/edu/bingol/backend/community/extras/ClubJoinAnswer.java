package edu.bingol.backend.community.extras;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Bir basvurucunun bir soruya yaniti; yalnizca MANAGE_MEMBERS yetkilileri okur. */
@Entity
@Table(name = "club_join_answer")
@Getter
@Setter
public class ClubJoinAnswer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    @Column(nullable = false)
    private Long questionId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 500)
    private String answer;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
