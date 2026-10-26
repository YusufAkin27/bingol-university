package edu.bingol.backend.messaging.room;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ChatRoomLinkRepository extends JpaRepository<ChatRoomLink, Long> {

    Optional<ChatRoomLink> findByKindAndRefId(RoomKind kind, Long refId);

    /** Konusma bir oda ise baglantisi (moderasyon yetkisi icin). */
    Optional<ChatRoomLink> findByConversationId(Long conversationId);

    /**
     * Baglantiyi atomik ekler; (tur, kaynak) zaten varsa 0 doner, hata firlatmaz (hata cagiran islemi
     * rollback-only yapardi).
     */
    @Transactional
    @Modifying
    @Query(value = """
            INSERT INTO chat_room_link (kind, ref_id, conversation_id, closed, created_at)
            VALUES (:kind, :ref, :conv, FALSE, :at) ON CONFLICT (kind, ref_id) DO NOTHING
            """, nativeQuery = true)
    int insertIfAbsent(@Param("kind") String kind, @Param("ref") Long refId, @Param("conv") Long conversationId,
                       @Param("at") Instant at);

    /** Aktif olmayan (askida/silinmis) kullanicilari tum odalardan cikarir; etkilenen satir sayisini doner. */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.leftAt = :now WHERE m.leftAt IS NULL "
            + "AND m.conversationId IN (SELECT l.conversationId FROM ChatRoomLink l) "
            + "AND m.userId IN (SELECT u.id FROM User u WHERE u.status <> edu.bingol.backend.user.UserStatus.ACTIVE)")
    int purgeInactiveUsers(@Param("now") Instant now);

    /** Odadaki tum aktif uyeleri cikarir (oda kapatma). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.leftAt = :now WHERE m.leftAt IS NULL AND m.conversationId = :cid")
    int leaveAll(@Param("cid") Long conversationId, @Param("now") Instant now);

    /** Konusma listesi gorunumu icin toplu arama. */
    List<ChatRoomLink> findByConversationIdIn(java.util.Collection<Long> conversationIds);

    List<ChatRoomLink> findByKind(RoomKind kind);
}
