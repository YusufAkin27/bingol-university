package edu.bingol.backend.mail.campaign;

import jakarta.persistence.LockModeType;
import jakarta.persistence.QueryHint;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.QueryHints;
import org.springframework.data.repository.query.Param;

public interface MailCampaignRepository extends JpaRepository<MailCampaign, Long> {

    Optional<MailCampaign> findByCreatedByAndRequestKey(Long createdBy, String requestKey);

    boolean existsByTemplateId(Long templateId);

    /** Zamani gelen veya gonderimi suren kampanyalarin kimlikleri (islem sirasi: en eski once). */
    @Query("""
            SELECT c.id FROM MailCampaign c
            WHERE c.status = edu.bingol.backend.mail.campaign.MailCampaign.Status.SENDING
               OR (c.status = edu.bingol.backend.mail.campaign.MailCampaign.Status.SCHEDULED AND c.scheduledAt <= :now)
            ORDER BY c.scheduledAt, c.id""")
    List<Long> findActiveIds(@Param("now") Instant now, Pageable pageable);

    /** Satiri kilitler; baska islemde kilitliyse atlar (PostgreSQL: FOR UPDATE SKIP LOCKED). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints(@QueryHint(name = "jakarta.persistence.lock.timeout", value = "-2"))
    @Query("SELECT c FROM MailCampaign c WHERE c.id = :id")
    Optional<MailCampaign> lockById(@Param("id") Long id);

    @Query("SELECT c.id FROM MailCampaign c WHERE (c.finishedAt IS NOT NULL AND c.finishedAt < :cutoff) "
            + "OR (c.finishedAt IS NULL AND c.status IN :idle AND c.updatedAt < :cutoff)")
    List<Long> findExpiredIds(@Param("cutoff") Instant cutoff, @Param("idle") Collection<MailCampaign.Status> idle);
}
