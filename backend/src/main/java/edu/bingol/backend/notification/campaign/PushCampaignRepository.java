package edu.bingol.backend.notification.campaign;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface PushCampaignRepository extends JpaRepository<PushCampaign, Long> {

    @Query("SELECT c FROM PushCampaign c WHERE (:cursor IS NULL OR c.id < :cursor) ORDER BY c.id DESC")
    List<PushCampaign> page(@Param("cursor") Long cursor, Pageable pageable);

    /**
     * Zamani gelen siradaki kampanyayi atomik olarak SENDING yapar ve id'sini doner.
     * SKIP LOCKED sayesinde birden fazla sunucu ayni kampanyayi iki kez gondermez.
     */
    @Transactional
    @Query(value = """
            UPDATE push_campaign SET status = 'SENDING', started_at = now()
            WHERE id = (SELECT id FROM push_campaign
                        WHERE status = 'SCHEDULED' AND scheduled_at <= now()
                        ORDER BY scheduled_at, id LIMIT 1 FOR UPDATE SKIP LOCKED)
            RETURNING id
            """, nativeQuery = true)
    Optional<Long> claimNext();

    /** Yalnizca hala SCHEDULED ise iptal eder (yaris durumunda 0 doner). */
    @Transactional
    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE PushCampaign c SET c.status = edu.bingol.backend.notification.campaign.PushCampaign.Status.CANCELLED WHERE c.id = :id AND c.status = edu.bingol.backend.notification.campaign.PushCampaign.Status.SCHEDULED")
    int cancelIfScheduled(@Param("id") Long id);
}
