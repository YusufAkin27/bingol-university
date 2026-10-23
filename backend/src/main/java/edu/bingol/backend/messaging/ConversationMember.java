package edu.bingol.backend.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Konusma uyeligi. Okundu bilgisi mesaj basina degil, uye basina imlecle (lastReadMessageId) tutulur. */
@Entity
@Table(name = "conversation_member")
@Getter
@Setter
public class ConversationMember {

    public enum Role { MEMBER, ADMIN }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long conversationId;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Role role = Role.MEMBER;

    @Column(nullable = false)
    private Instant joinedAt = Instant.now();

    /** Doluysa uye ayrildi/cikarildi: erisim yok. */
    private Instant leftAt;

    @Column(nullable = false)
    private Long lastReadMessageId = 0L;

    public static ConversationMember of(Long conversationId, Long userId, Role role) {
        ConversationMember m = new ConversationMember();
        m.conversationId = conversationId;
        m.userId = userId;
        m.role = role;
        return m;
    }

    public boolean isAdmin() {
        return role == Role.ADMIN;
    }
}
