package edu.bingol.backend.messaging.media;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MessageAttachmentRepository extends JpaRepository<MessageAttachment, Long> {

    boolean existsByStorageKey(String storageKey);

    List<MessageAttachment> findByMessageIdIn(Collection<Long> messageIds);

    List<MessageAttachment> findByMessageId(Long messageId);

    List<MessageAttachment> findByUploaderId(Long uploaderId);

    long countByUploaderIdAndMessageIdIsNull(Long uploaderId);

    /** Baglanmamis ve `before`dan eski yuklemeler (temizleyici). */
    @Query("SELECT a FROM MessageAttachment a WHERE a.messageId IS NULL AND a.createdAt < :before ORDER BY a.id")
    List<MessageAttachment> stale(@Param("before") Instant before, org.springframework.data.domain.Pageable page);

    /**
     * Atomik "sahiplen": yalnizca ayni konusmada, yukleyen gonderen, henuz baglanmamis ve gizli olmayan ekler
     * mesaja baglanir. Donen sayi ids.size()'dan azsa en az biri gecersiz/baskasinin/kullanilmis demektir.
     */
    @Modifying(flushAutomatically = true)
    @Query("UPDATE MessageAttachment a SET a.messageId = :mid WHERE a.id IN :ids AND a.uploaderId = :uid "
            + "AND a.conversationId = :cid AND a.messageId IS NULL AND a.hiddenAt IS NULL")
    int claim(@Param("mid") Long messageId, @Param("ids") Collection<Long> ids, @Param("uid") Long uploaderId,
              @Param("cid") Long conversationId);

    /** Yalnizca hala baglanmamissa siler (temizleyici ile mesaja baglama yarisi); silinen satir sayisi doner. */
    @org.springframework.transaction.annotation.Transactional
    @Modifying
    @Query("DELETE FROM MessageAttachment a WHERE a.id = :id AND a.messageId IS NULL")
    int deleteIfUnclaimed(@Param("id") Long id);
}
