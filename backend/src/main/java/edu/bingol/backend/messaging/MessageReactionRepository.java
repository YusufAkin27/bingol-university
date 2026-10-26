package edu.bingol.backend.messaging;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface MessageReactionRepository extends JpaRepository<MessageReaction, Long> {

    /** [messageId, emoji, adet] */
    @Query("SELECT r.messageId, r.emoji, COUNT(r) FROM MessageReaction r WHERE r.messageId IN :ids "
            + "GROUP BY r.messageId, r.emoji ORDER BY r.messageId, COUNT(r) DESC, r.emoji")
    List<Object[]> counts(@Param("ids") Collection<Long> messageIds);

    @Query("SELECT r FROM MessageReaction r WHERE r.userId = :uid AND r.messageId IN :ids")
    List<MessageReaction> mine(@Param("uid") Long userId, @Param("ids") Collection<Long> messageIds);

    /** Tek istekte atomik: yoksa ekler, varsa emojiyi degistirir (es zamanli istekte hata firlatmaz). */
    @Transactional
    @Modifying
    @Query(value = """
            INSERT INTO message_reaction (message_id, user_id, emoji, created_at) VALUES (:mid, :uid, :emoji, :at)
            ON CONFLICT (message_id, user_id) DO UPDATE SET emoji = EXCLUDED.emoji, created_at = EXCLUDED.created_at
            """, nativeQuery = true)
    int upsert(@Param("mid") Long messageId, @Param("uid") Long userId, @Param("emoji") String emoji,
               @Param("at") Instant at);

    @Transactional
    @Modifying
    @Query("DELETE FROM MessageReaction r WHERE r.messageId = :mid AND r.userId = :uid")
    int remove(@Param("mid") Long messageId, @Param("uid") Long userId);

    @Transactional
    @Modifying
    @Query("DELETE FROM MessageReaction r WHERE r.messageId = :mid")
    int removeAll(@Param("mid") Long messageId);

    /** KVKK dis aktarim: kullanicinin verdigi tepkiler (yeni -> eski). */
    @Query("SELECT r FROM MessageReaction r WHERE r.userId = :uid ORDER BY r.id DESC")
    List<MessageReaction> givenBy(@Param("uid") Long userId, Pageable pageable);
}
