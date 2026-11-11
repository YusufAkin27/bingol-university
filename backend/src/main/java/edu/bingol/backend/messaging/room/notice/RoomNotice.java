package edu.bingol.backend.messaging.room.notice;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Sohbet odasi duyurusu (V1840). Yumusak silme: deletedAt (sahip/yetkili), hiddenAt (moderasyon). */
@Entity
@Table(name = "room_notice")
@Getter
@Setter
public class RoomNotice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long conversationId;

    @Column(nullable = false)
    private Long authorId;

    @Column(nullable = false, length = 80)
    private String title;

    @Column(nullable = false, length = 600)
    private String body;

    @Column(nullable = false)
    private boolean pinned;

    @Column(nullable = false)
    private int seenCount;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    private Instant deletedAt;

    private Instant hiddenAt;

    public boolean isLive() {
        return deletedAt == null && hiddenAt == null;
    }
}
