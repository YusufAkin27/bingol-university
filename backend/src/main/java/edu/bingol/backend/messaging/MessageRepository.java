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

    /** {@link #before} + "sohbeti sil" alt siniri (`cleared`: bu id ve oncesi gorunmez). */
    @Query("SELECT m FROM Message m WHERE m.conversationId = :cid AND m.createdAt >= :since AND m.id > :cleared "
            + "AND (m.suppressed = false OR m.senderId = :viewer) "
            + "AND (:before IS NULL OR m.id < :before) ORDER BY m.id DESC")
    List<Message> beforeCleared(@Param("cid") Long conversationId, @Param("since") Instant since,
                                @Param("cleared") Long cleared, @Param("viewer") Long viewerId,
                                @Param("before") Long before, Pageable pageable);

    /** {@link #after} + "sohbeti sil" alt siniri. */
    @Query("SELECT m FROM Message m WHERE m.conversationId = :cid AND m.createdAt >= :since AND m.id > :after "
            + "AND m.id > :cleared AND (m.suppressed = false OR m.senderId = :viewer) ORDER BY m.id ASC")
    List<Message> afterCleared(@Param("cid") Long conversationId, @Param("since") Instant since,
                               @Param("cleared") Long cleared, @Param("viewer") Long viewerId,
                               @Param("after") Long after, Pageable pageable);

    /** Golge engel: (from, to] araliginda `owner`in en kucuk bastirilmis mesaj kimligi (yoksa null). */
    @Query("SELECT MIN(m.id) FROM Message m WHERE m.conversationId = :cid AND m.senderId = :owner AND m.suppressed = true "
            + "AND m.id > :from AND m.id <= :to")
    Long minSuppressedId(@Param("cid") Long conversationId, @Param("owner") Long owner, @Param("from") Long from,
                         @Param("to") Long to);

    /**
     * Konusma basina okunmamis sayisi: [conversationId, adet]. TEK tanim (liste satiri ve rozet ayni sorguyu kullanir):
     * ayrilmamis uyelik, katilma sonrasi, okunmamis, kendi/gizlenen/silinen ve `excluded` (engel iliskisi) gonderenler haric.
     * `excluded` bos olmamali (cagiran -1 gibi bir yer tutucu ekler).
     */
    @Query("SELECT m.conversationId, COUNT(m) FROM Message m, ConversationMember cm "
            + "WHERE cm.conversationId = m.conversationId AND cm.userId = :uid AND cm.leftAt IS NULL "
            + "AND m.conversationId IN :cids AND m.createdAt >= cm.joinedAt "
            + "AND m.id > cm.lastReadMessageId AND m.id > cm.clearedUpToMessageId AND m.suppressed = false AND m.senderId <> :uid AND m.senderId NOT IN :excluded "
            + "AND m.hiddenAt IS NULL AND m.deletedAt IS NULL GROUP BY m.conversationId")
    List<Object[]> unreadCounts(@Param("uid") Long userId, @Param("cids") Collection<Long> conversationIds,
                                @Param("excluded") Collection<Long> excludedSenders);

    /** `NOT IN` bos kumeyle calismaz: engel iliskisi yoksa gecersiz bir yer tutucu id doner. */
    static List<Long> excludedSenders(Collection<Long> related) {
        return related.isEmpty() ? List.of(-1L) : List.copyOf(related);
    }

    /** Iletildi ack'i icin: baskalarinin (kendi olmayan) `upTo`'ya kadarki en son mesaj kimligi; yoksa null. */
    @Query("SELECT MAX(m.id) FROM Message m WHERE m.conversationId = :cid AND m.id <= :upTo AND m.senderId <> :uid")
    Long maxIdFromOthers(@Param("cid") Long conversationId, @Param("upTo") Long upTo, @Param("uid") Long userId);

    /** (from, to] araliginda `exceptUid` disindaki gondericiler (grup makbuz toplulastirmasi). */
    @Query("SELECT DISTINCT m.senderId FROM Message m WHERE m.conversationId = :cid AND m.id > :from AND m.id <= :to "
            + "AND m.senderId <> :uid")
    List<Long> sendersInRange(@Param("cid") Long conversationId, @Param("from") Long from, @Param("to") Long to,
                              @Param("uid") Long exceptUid);

    /** Bir gondericinin `to`'ya kadarki en yeni mesajlari (yeni -> eski; sayfa siniri cagirandadir). */
    @Query("SELECT m FROM Message m WHERE m.conversationId = :cid AND m.senderId = :sender AND m.id <= :to "
            + "AND m.id > :from AND m.deletedAt IS NULL AND m.hiddenAt IS NULL ORDER BY m.id DESC")
    List<Message> ownedInRange(@Param("cid") Long conversationId, @Param("sender") Long senderId,
                               @Param("from") Long from, @Param("to") Long to, Pageable pageable);

    /**
     * Duzenleme: yeni sifreli govdeyi yazar (eski sifreli icerik ezilir; gecmis tutulmaz). Silinmis/gizlenmis
     * mesajda 0 doner.
     */
    @Transactional
    @Modifying
    @Query("UPDATE Message m SET m.bodyCiphertext = :ct, m.bodyNonce = :nonce, m.keyVersion = :kv, m.editedAt = :at "
            + "WHERE m.id = :id AND m.deletedAt IS NULL AND m.hiddenAt IS NULL")
    int applyEdit(@Param("id") Long id, @Param("ct") byte[] ciphertext, @Param("nonce") byte[] nonce,
                  @Param("kv") Integer keyVersion, @Param("at") Instant at);

    /** Herkes icin silme (tombstone): sifreli icerik, nonce, anahtar surumu ve yanit bagi temizlenir. */
    @Transactional
    @Modifying
    @Query("UPDATE Message m SET m.bodyCiphertext = NULL, m.bodyNonce = NULL, m.keyVersion = NULL, "
            + "m.replyToMessageId = NULL, m.editedAt = NULL, m.deletedAt = :at, m.deletedBy = :by "
            + "WHERE m.id = :id AND m.deletedAt IS NULL")
    int tombstone(@Param("id") Long id, @Param("at") Instant at, @Param("by") Long deletedBy);

    @Transactional
    @Modifying
    @Query("UPDATE Message m SET m.hiddenAt = :at WHERE m.id = :id AND m.hiddenAt IS NULL")
    int hide(@Param("id") Long id, @Param("at") Instant at);
}
