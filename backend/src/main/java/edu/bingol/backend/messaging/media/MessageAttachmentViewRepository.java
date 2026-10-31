package edu.bingol.backend.messaging.media;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface MessageAttachmentViewRepository extends JpaRepository<MessageAttachmentView, MessageAttachmentView.Key> {

    boolean existsByAttachmentIdAndUserId(Long attachmentId, Long userId);

    /** Govdesi tamamen teslim edilmis acis sayisi (devam eden talepler sayilmaz). */
    long countByAttachmentIdAndDeliveredAtIsNotNull(Long attachmentId);

    @Query("SELECT v.attachmentId FROM MessageAttachmentView v WHERE v.userId = :uid AND v.attachmentId IN :ids "
            + "AND v.deliveredAt IS NOT NULL")
    List<Long> viewedBy(@Param("uid") Long userId, @Param("ids") Collection<Long> attachmentIds);

    /** Bu eklerden en az bir kez acilmis olanlar (gonderen gorunumu). */
    @Query("SELECT DISTINCT v.attachmentId FROM MessageAttachmentView v WHERE v.attachmentId IN :ids "
            + "AND v.deliveredAt IS NOT NULL")
    List<Long> viewedByAnyone(@Param("ids") Collection<Long> attachmentIds);

    /** Govde yazildi: talebi teslim edilmis yapar (1 = bu cagri yapti). */
    @Transactional
    @Modifying
    @Query("UPDATE MessageAttachmentView v SET v.deliveredAt = :at WHERE v.attachmentId = :aid AND v.userId = :uid "
            + "AND v.deliveredAt IS NULL")
    int markDelivered(@Param("aid") Long attachmentId, @Param("uid") Long userId, @Param("at") Instant at);

    /** Yazim yarim kaldi: bekleyen talebi birakir (tuketilmedi; kullanici yeniden acabilir). Teslim edileni silmez. */
    @Transactional
    @Modifying
    @Query("DELETE FROM MessageAttachmentView v WHERE v.attachmentId = :aid AND v.userId = :uid AND v.deliveredAt IS NULL")
    int releaseClaim(@Param("aid") Long attachmentId, @Param("uid") Long userId);

    /**
     * Teslimden sonra tek yeniden acis: yalniz teslim from..to araliginda ve henuz yeniden acilmadiysa
     * (1 = bu cagri hakki aldi; eszamanli ikinci istek 0 alir).
     */
    @Transactional
    @Modifying
    @Query("UPDATE MessageAttachmentView v SET v.reopenedAt = :at WHERE v.attachmentId = :aid AND v.userId = :uid "
            + "AND v.reopenedAt IS NULL AND v.deliveredAt IS NOT NULL AND v.deliveredAt >= :from AND v.deliveredAt <= :to")
    int claimReopen(@Param("aid") Long attachmentId, @Param("uid") Long userId, @Param("at") Instant at,
                    @Param("from") Instant from, @Param("to") Instant to);
}
