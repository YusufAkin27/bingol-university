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

    /** KVKK dis aktarim: kullanicinin kendi gonderdigi GORUNUR mesajlar (yeni -> eski); herkes icin silinenler haric. */
    @Query("SELECT m FROM Message m WHERE m.senderId = :uid AND m.deletedAt IS NULL ORDER BY m.id DESC")
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
            + "AND m.id > cm.lastReadMessageId AND m.senderId <> :uid AND m.hiddenAt IS NULL AND m.deletedAt IS NULL "
            + "GROUP BY m.conversationId")
    List<Object[]> unreadCounts(@Param("uid") Long userId, @Param("cids") Collection<Long> conversationIds);

    /** Kullanicinin TUM aktif konusmalarindaki okunmamis sayilari: [conversationId, adet] (yalniz adedi > 0 olanlar). */
    @Query("SELECT m.conversationId, COUNT(m) FROM Message m, ConversationMember cm "
            + "WHERE cm.conversationId = m.conversationId AND cm.userId = :uid AND cm.leftAt IS NULL "
            + "AND m.createdAt >= cm.joinedAt "
            + "AND m.id > cm.lastReadMessageId AND m.senderId <> :uid AND m.hiddenAt IS NULL AND m.deletedAt IS NULL "
            + "GROUP BY m.conversationId")
    List<Object[]> unreadAll(@Param("uid") Long userId);

    /**
     * Duzenleme: yeni sifreli govdeyi yazar. Eski sifreli surum once {@link #archiveRevision} ile
     * `message_revision`'a kopyalanir (gecmis saklanir). Silinmis/gizlenmis mesajda 0 doner.
     */
    @Transactional
    @Modifying
    @Query("UPDATE Message m SET m.bodyCiphertext = :ct, m.bodyNonce = :nonce, m.keyVersion = :kv, m.editedAt = :at "
            + "WHERE m.id = :id AND m.deletedAt IS NULL AND m.hiddenAt IS NULL")
    int applyEdit(@Param("id") Long id, @Param("ct") byte[] ciphertext, @Param("nonce") byte[] nonce,
                  @Param("kv") Integer keyVersion, @Param("at") Instant at);

    /** Mesajin gecerli sifreli govdesini duzenleme gecmisine kopyalar (yonetici goruntuleyici icin; T24). */
    @Transactional
    @Modifying
    @Query(value = "INSERT INTO message_revision (message_id, body_ciphertext, body_nonce, key_version, revised_at) "
            + "SELECT id, body_ciphertext, body_nonce, key_version, COALESCE(edited_at, created_at) FROM message "
            + "WHERE id = :id AND body_ciphertext IS NOT NULL AND body_nonce IS NOT NULL AND key_version IS NOT NULL "
            + "AND deleted_at IS NULL AND hidden_at IS NULL", nativeQuery = true)
    int archiveRevision(@Param("id") Long id);

    /**
     * Herkes icin silme (tombstone): yalnizca deleted_at/deleted_by isaretlenir. Sifreli govde, duzenleme ve yanit
     * bagi SAKLANIR (yonetici goruntuleyici; saklama suresi: app.chat.deleted-retention-days). Kullanici API'si
     * silinmis mesaj icin icerik donmez.
     */
    @Transactional
    @Modifying
    @Query("UPDATE Message m SET m.deletedAt = :at, m.deletedBy = :by WHERE m.id = :id AND m.deletedAt IS NULL")
    int tombstone(@Param("id") Long id, @Param("at") Instant at, @Param("by") Long deletedBy);

    /** Saklama suresi dolan silinmis mesajlari (tepki/duzenleme gecmisi CASCADE) kalici siler; silinen satir sayisi doner. */
    @Transactional
    @Modifying
    @Query("DELETE FROM Message m WHERE m.deletedAt IS NOT NULL AND m.deletedAt < :cutoff")
    int purgeDeletedBefore(@Param("cutoff") Instant cutoff);

    @Transactional
    @Modifying
    @Query("UPDATE Message m SET m.hiddenAt = :at WHERE m.id = :id AND m.hiddenAt IS NULL")
    int hide(@Param("id") Long id, @Param("at") Instant at);
}
