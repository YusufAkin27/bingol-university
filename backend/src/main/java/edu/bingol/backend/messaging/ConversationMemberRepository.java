package edu.bingol.backend.messaging;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ConversationMemberRepository extends JpaRepository<ConversationMember, Long> {

    Optional<ConversationMember> findByConversationIdAndUserId(Long conversationId, Long userId);

    /** Yetki kontrolunun tek noktasi: yalnizca ayrilmamis uyeler. */
    Optional<ConversationMember> findByConversationIdAndUserIdAndLeftAtIsNull(Long conversationId, Long userId);

    List<ConversationMember> findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(Long conversationId);

    List<ConversationMember> findByConversationIdInAndLeftAtIsNull(Collection<Long> conversationIds);

    long countByConversationIdAndLeftAtIsNull(Long conversationId);

    /** Imleci yalnizca ileri tasir; degisen satir sayisini doner (0 = zaten bu noktada ya da ilerideydi). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.lastReadMessageId = :mid, "
            + "m.lastDeliveredMessageId = CASE WHEN m.lastDeliveredMessageId < :mid THEN :mid ELSE m.lastDeliveredMessageId END "
            + "WHERE m.conversationId = :cid AND m.userId = :uid AND m.lastReadMessageId < :mid")
    int advanceRead(@Param("cid") Long conversationId, @Param("uid") Long userId, @Param("mid") Long messageId);

    /** Iletildi imlecini yalnizca ileri tasir (okundu imleci ayri; okuma zaten iletildiyi de ilerletir). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.lastDeliveredMessageId = :mid "
            + "WHERE m.conversationId = :cid AND m.userId = :uid AND m.leftAt IS NULL AND m.lastDeliveredMessageId < :mid")
    int advanceDelivered(@Param("cid") Long conversationId, @Param("uid") Long userId, @Param("mid") Long messageId);

    List<ConversationMember> findByUserIdAndLeftAtIsNull(Long userId);

    /** Yeni mesaj gelince "yapiskan" olmayan arsivleri kaldirir (herkes icin). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.archivedAt = NULL "
            + "WHERE m.conversationId = :cid AND m.archivedAt IS NOT NULL AND m.archiveSticky = false")
    int unarchiveOnMessage(@Param("cid") Long conversationId);

    /** Yeni mesaj gelince "sohbeti silen" uyelerin listesinde konusma yeniden belirir (yalniz yeni mesajlarla). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.hiddenAt = NULL "
            + "WHERE m.conversationId = :cid AND m.hiddenAt IS NOT NULL AND m.leftAt IS NULL")
    int unhideOnMessage(@Param("cid") Long conversationId);

    /** Golge engel: yalniz gonderenin kendi bastirilmis son mesaj imleci (ileri). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.lastOwnSuppressedMessageId = :mid "
            + "WHERE m.conversationId = :cid AND m.userId = :uid AND m.lastOwnSuppressedMessageId < :mid")
    int advanceOwnSuppressed(@Param("cid") Long conversationId, @Param("uid") Long userId, @Param("mid") Long messageId);

    /** Tek uyenin "sohbeti sil" gizlemesini kaldirir (bastirilmis mesaj atan gonderen). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.hiddenAt = NULL "
            + "WHERE m.conversationId = :cid AND m.userId = :uid AND m.hiddenAt IS NOT NULL")
    int unhideMember(@Param("cid") Long conversationId, @Param("uid") Long userId);

    /** Iki kullanicinin ortak (ikisi de ayrilmamis) bir konusmasi var mi. */
    @Query("SELECT COUNT(a) > 0 FROM ConversationMember a, ConversationMember b WHERE a.conversationId = b.conversationId "
            + "AND a.userId = :a AND b.userId = :b AND a.leftAt IS NULL AND b.leftAt IS NULL")
    boolean shareConversation(@Param("a") Long userA, @Param("b") Long userB);
}
