package edu.bingol.backend.messaging;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface MessageRepository extends JpaRepository<Message, Long> {

    Optional<Message> findByConversationIdAndSenderIdAndClientId(Long conversationId, Long senderId, String clientId);

    /** KVKK dis aktarim: kullanicinin kendi gonderdigi mesajlar (yeni -> eski). */
    @Query("SELECT m FROM Message m WHERE m.senderId = :uid ORDER BY m.id DESC")
    List<Message> sentBy(@Param("uid") Long userId, Pageable pageable);

    /** Geriye dogru gecmis (yeni -> eski). `since`: uyenin katilma zamani, oncesi gorunmez. */
    @Query("SELECT m FROM Message m WHERE m.conversationId = :cid AND m.createdAt >= :since "
            + "AND (:before IS NULL OR m.id < :before) ORDER BY m.id DESC")
    List<Message> before(@Param("cid") Long conversationId, @Param("since") Instant since,
                         @Param("before") Long before, Pageable pageable);

    /** Kacirilanlari tamamlama (eski -> yeni). */
    @Query("SELECT m FROM Message m WHERE m.conversationId = :cid AND m.createdAt >= :since AND m.id > :after "
            + "ORDER BY m.id ASC")
    List<Message> after(@Param("cid") Long conversationId, @Param("since") Instant since,
                        @Param("after") Long after, Pageable pageable);

    /** Konusma basina okunmamis sayisi: [conversationId, adet]. Kendi ve gizlenen mesajlar sayilmaz. */
    @Query("SELECT m.conversationId, COUNT(m) FROM Message m, ConversationMember cm "
            + "WHERE cm.conversationId = m.conversationId AND cm.userId = :uid AND m.conversationId IN :cids "
            + "AND m.id > cm.lastReadMessageId AND m.senderId <> :uid AND m.hiddenAt IS NULL "
            + "GROUP BY m.conversationId")
    List<Object[]> unreadCounts(@Param("uid") Long userId, @Param("cids") Collection<Long> conversationIds);

    @Transactional
    @Modifying
    @Query("UPDATE Message m SET m.hiddenAt = :at WHERE m.id = :id AND m.hiddenAt IS NULL")
    int hide(@Param("id") Long id, @Param("at") Instant at);
}
