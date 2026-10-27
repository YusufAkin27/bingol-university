package edu.bingol.backend.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Duration;
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

    /** Iletildi imleci (okundu >= iletildi: okuma iletilmis sayilir); istemci ack'iyle ilerler. */
    @Column(nullable = false)
    private Long lastDeliveredMessageId = 0L;

    /** "Sohbeti sil": bu kimlige kadar (dahil) mesajlar bu uyeye bir daha gosterilmez. */
    @Column(nullable = false)
    private Long clearedUpToMessageId = 0L;

    /** Golge engel: uyenin kendi bastirilmis son mesaji (kendi listesinde gorur). */
    @Column(nullable = false)
    private Long lastOwnSuppressedMessageId = 0L;

    /** Doluysa konusma uyenin listesinden kaldirilmis; yeni mesajla temizlenir. */
    private Instant hiddenAt;

    /** Doluysa bu zamana kadar sessiz: push/uygulama ici bildirim yok, okunmamis sayaci artar. */
    private Instant mutedUntil;

    /** Doluysa konusma kullanicinin arsivinde. */
    private Instant archivedAt;

    /** true: yeni mesaj gelse de arsivde kalir. */
    @Column(nullable = false)
    private boolean archiveSticky = false;

    /** Sure secenekleri en fazla 1 yildir; bunun cok ustu "suresiz" sayilir (ConversationPrefsService.FOREVER 100 yil). */
    private static final Duration FOREVER_THRESHOLD = Duration.ofDays(365L * 10);

    public boolean isMuted() {
        return mutedUntil != null && mutedUntil.isAfter(Instant.now());
    }

    public boolean isMutedForever() {
        return mutedUntil != null && mutedUntil.isAfter(Instant.now().plus(FOREVER_THRESHOLD));
    }

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
