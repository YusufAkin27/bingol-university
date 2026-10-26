package edu.bingol.backend.messaging.room;

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

/** Bir grup konusmasini (tur, kaynak id) ikilisine baglar: kulup/etkinlik sohbet odasi. */
@Entity
@Table(name = "chat_room_link")
@Getter
@Setter
public class ChatRoomLink {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private RoomKind kind;

    @Column(nullable = false)
    private Long refId;

    @Column(nullable = false)
    private Long conversationId;

    /** Kapali odada kimse uye degildir; yeni uye eklenmez. */
    @Column(nullable = false)
    private boolean closed;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
