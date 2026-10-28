package edu.bingol.backend.messaging;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Conversation {

    public enum Type { DIRECT, GROUP }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Type type;

    /** Yalnizca birebir: "kucukId:buyukId" (benzersiz). */
    @Column(length = 41, unique = true)
    private String directKey;

    @Column(length = 100)
    private String title;

    /** Yalnizca kullanici gruplari: grup fotografi (/files/avatars/...). */
    @Column(length = 300)
    private String avatarUrl;

    @Column(nullable = false)
    private Long createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Long lastMessageId;

    /** Bastirilmamis son mesaj (golge engel); bastirma yoksa lastMessageId ile ayni. */
    private Long lastVisibleMessageId;

    /** En az bir bastirilmis mesaj var: gecmis/liste gorunurluk suzgeci kullanir. */
    @jakarta.persistence.Column(nullable = false)
    private boolean shadowed = false;

    private Instant lastMessageAt;

    /** Yonetici kapatmasi (P08): doluysa yeni mesaj gonderilemez (409 CONVERSATION_CLOSED); gecmis ve uyelikler korunur. */
    private Instant closedAt;

    private Long closedBy;

    @Column(length = 300)
    private String closedReason;

    public boolean isClosed() {
        return closedAt != null;
    }

    public static String directKey(Long a, Long b) {
        return Math.min(a, b) + ":" + Math.max(a, b);
    }
}
