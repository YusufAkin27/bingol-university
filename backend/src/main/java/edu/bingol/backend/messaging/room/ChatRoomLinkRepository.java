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

    /** Aktif olmayan (askida/silinmis) kullanicilari tum odalardan cikarir; etkilenen satir sayisini doner (tur basina en cok 200, kalani sonraki turda). */
    @Transactional
    @Modifying
    @Query(value = "UPDATE conversation_member SET left_at = :now WHERE id IN (SELECT m.id FROM conversation_member m "
            + "WHERE m.left_at IS NULL AND m.conversation_id IN (SELECT l.conversation_id FROM chat_room_link l) "
            + "AND m.user_id IN (SELECT u.id FROM app_user u WHERE u.status <> 'ACTIVE') LIMIT 200)", nativeQuery = true)
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
