package edu.bingol.backend.messaging;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ConversationRepository extends JpaRepository<Conversation, Long> {

    Optional<Conversation> findByDirectKey(String directKey);

    /** Satir kilidi: grup uye sayisi kontrolu ile eklemeyi es zamanli isteklere karsi seri hale getirir (50 siniri). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c.id FROM Conversation c WHERE c.id = :id")
    Optional<Long> lockById(@Param("id") Long id);

    /**
     * Birebir konusmayi atomik olusturur; anahtar zaten varsa (yaris kosulu dahil) 0 doner, hata firlatmaz.
     * (Hata firlatsaydi cagiran islem rollback-only olurdu.)
     */
    @Transactional
    @Modifying
    @Query(value = """
            INSERT INTO conversation (type, direct_key, created_by, created_at)
            VALUES ('DIRECT', :key, :by, :at) ON CONFLICT (direct_key) DO NOTHING
            """, nativeQuery = true)
    int insertDirect(@Param("key") String directKey, @Param("by") Long createdBy, @Param("at") Instant createdAt);

    /** Yalnizca ileri: eski bir id son mesaji geri almaz. */
    @Transactional
    @Modifying
    @Query("UPDATE Conversation c SET c.lastMessageId = :mid, c.lastMessageAt = :at "
            + "WHERE c.id = :id AND (c.lastMessageId IS NULL OR c.lastMessageId < :mid)")
    int touchLastMessage(@Param("id") Long id, @Param("mid") Long messageId, @Param("at") Instant at);

    /** Bastirilmamis mesaj: gorunur son mesaj imleci ileri. */
    @Transactional
    @Modifying
    @Query("UPDATE Conversation c SET c.lastVisibleMessageId = :mid "
            + "WHERE c.id = :id AND (c.lastVisibleMessageId IS NULL OR c.lastVisibleMessageId < :mid)")
    int touchLastVisible(@Param("id") Long id, @Param("mid") Long messageId);

    @Transactional
    @Modifying
    @Query("UPDATE Conversation c SET c.shadowed = true WHERE c.id = :id AND c.shadowed = false")
    int markShadowed(@Param("id") Long id);

    /** Kullanicinin (ayrilmadigi) mesajli konusmalari, en yeni mesaj once. Imlec = son mesaj id'si (benzersiz). */
    @Query("SELECT c FROM Conversation c, ConversationMember m WHERE m.conversationId = c.id AND m.userId = :uid "
            + "AND m.leftAt IS NULL AND m.hiddenAt IS NULL AND c.lastMessageId IS NOT NULL "
            + "AND (CASE WHEN c.shadowed = true THEN GREATEST(COALESCE(c.lastVisibleMessageId, 0L), m.lastOwnSuppressedMessageId) "
            + "ELSE c.lastMessageId END) > 0 "
            + "AND ((:archived = true AND m.archivedAt IS NOT NULL) OR (:archived = false AND m.archivedAt IS NULL)) "
            + "AND (:cursor IS NULL OR (CASE WHEN c.shadowed = true THEN GREATEST(COALESCE(c.lastVisibleMessageId, 0L), "
            + "m.lastOwnSuppressedMessageId) ELSE c.lastMessageId END) < :cursor) "
            + "ORDER BY (CASE WHEN c.shadowed = true THEN GREATEST(COALESCE(c.lastVisibleMessageId, 0L), "
            + "m.lastOwnSuppressedMessageId) ELSE c.lastMessageId END) DESC")
    List<Conversation> page(@Param("uid") Long userId, @Param("cursor") Long cursor,
                            @Param("archived") boolean archived, Pageable pageable);
}
