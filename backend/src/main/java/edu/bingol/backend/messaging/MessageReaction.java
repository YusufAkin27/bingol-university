package edu.bingol.backend.messaging;

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

/** Mesaj tepkisi: mesaj basina kullanici basina en fazla bir emoji (degistirmek = ustune yazmak). */
@Entity
@Table(name = "message_reaction", uniqueConstraints = @UniqueConstraint(name = "chf92_uq_reaction",
        columnNames = {"message_id", "user_id"}))
@Getter
@Setter
public class MessageReaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long messageId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 16)
    private String emoji;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
