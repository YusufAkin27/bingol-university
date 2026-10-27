package edu.bingol.backend.messaging.media;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MessageAttachmentViewRepository extends JpaRepository<MessageAttachmentView, MessageAttachmentView.Key> {

    boolean existsByAttachmentIdAndUserId(Long attachmentId, Long userId);

    long countByAttachmentId(Long attachmentId);

    @Query("SELECT v.attachmentId FROM MessageAttachmentView v WHERE v.userId = :uid AND v.attachmentId IN :ids")
    List<Long> viewedBy(@Param("uid") Long userId, @Param("ids") Collection<Long> attachmentIds);

    /** Bu eklerden en az bir kez acilmis olanlar (gonderen gorunumu). */
    @Query("SELECT DISTINCT v.attachmentId FROM MessageAttachmentView v WHERE v.attachmentId IN :ids")
    List<Long> viewedByAnyone(@Param("ids") Collection<Long> attachmentIds);
}
