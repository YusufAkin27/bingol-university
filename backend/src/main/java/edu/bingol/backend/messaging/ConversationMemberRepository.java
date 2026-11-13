package edu.bingol.backend.messaging;

import java.time.Instant;
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

    /** Kullanicinin verilen konusmalardaki AKTIF uyelikleri (konusma kimlikleri). */
    @Query("SELECT m.conversationId FROM ConversationMember m WHERE m.leftAt IS NULL AND m.userId = :uid "
            + "AND m.conversationId IN :cids")
    List<Long> activeConversationIds(@Param("uid") Long userId, @Param("cids") Collection<Long> conversationIds);

    /** Konusma basina aktif uye sayisi: [conversationId, adet] (liste/makbuz kararinda uyeleri yuklemeden). */
    @Query("SELECT m.conversationId, COUNT(m) FROM ConversationMember m "
            + "WHERE m.conversationId IN :cids AND m.leftAt IS NULL GROUP BY m.conversationId")
    List<Object[]> activeCounts(@Param("cids") Collection<Long> conversationIds);

    /** Kullanicinin verilen konusmalardaki kendi (ayrilmamis) uyelik satirlari. */
    @Query("SELECT m FROM ConversationMember m WHERE m.userId = :uid AND m.conversationId IN :cids AND m.leftAt IS NULL")
    List<ConversationMember> findMine(@Param("uid") Long userId, @Param("cids") Collection<Long> conversationIds);

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

    /**
     * Sessize alma tercihini YALNIZ ilgili kolona yazar (FIX-P03, A09#8): tam satir `save` okunmus bayat imlecleri
     * (okundu/iletildi) eszamanli ilerlemenin uzerine geri yazabiliyordu.
     */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.mutedUntil = :until WHERE m.conversationId = :cid AND m.userId = :uid")
    int updateMute(@Param("cid") Long conversationId, @Param("uid") Long userId, @Param("until") Instant until);

    /** Arsiv tercihini yalniz ilgili kolonlara yazar (bkz. {@link #updateMute}). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.archivedAt = :at, m.archiveSticky = :sticky "
            + "WHERE m.conversationId = :cid AND m.userId = :uid")
    int updateArchive(@Param("cid") Long conversationId, @Param("uid") Long userId, @Param("at") Instant at,
                      @Param("sticky") boolean sticky);

    /** Tek uyenin "sohbeti sil" gizlemesini kaldirir (bastirilmis mesaj atan gonderen). */
    @Transactional
    @Modifying
    @Query("UPDATE ConversationMember m SET m.hiddenAt = NULL "
            + "WHERE m.conversationId = :cid AND m.userId = :uid AND m.hiddenAt IS NOT NULL")
    int unhideMember(@Param("cid") Long conversationId, @Param("uid") Long userId);

    /** Bekleyen mesaj istegi / grup daveti sayisi (T-026). */
    @Query("SELECT COUNT(m) FROM ConversationMember m, Conversation c WHERE c.id = m.conversationId "
            + "AND m.userId = :uid AND m.leftAt IS NULL "
            + "AND m.requestState = edu.bingol.backend.messaging.ConversationMember.RequestState.PENDING "
            // QA: engelledigim kisinin birebir istegi rozete girmez (ConversationRepository.requests ile ayni kural)
            + "AND NOT (c.type = edu.bingol.backend.messaging.Conversation.Type.DIRECT AND EXISTS (SELECT 1 FROM "
            + "ConversationMember o, edu.bingol.backend.moderation.UserBlock b WHERE o.conversationId = c.id "
            + "AND o.userId <> :uid AND b.blockerId = :uid AND b.blockedId = o.userId))")
    long countPending(@Param("uid") Long userId);

    /** Iki kullanicinin ortak (ikisi de ayrilmamis VE ikisi de kabul etmis) bir konusmasi var mi (presence: karsilikli kabul). */
    @Query("SELECT COUNT(a) > 0 FROM ConversationMember a, ConversationMember b WHERE a.conversationId = b.conversationId "
            + "AND a.userId = :a AND b.userId = :b AND a.leftAt IS NULL AND b.leftAt IS NULL "
            + "AND a.requestState = edu.bingol.backend.messaging.ConversationMember.RequestState.ACCEPTED "
            + "AND b.requestState = edu.bingol.backend.messaging.ConversationMember.RequestState.ACCEPTED")
    boolean shareConversation(@Param("a") Long userA, @Param("b") Long userB);
}
