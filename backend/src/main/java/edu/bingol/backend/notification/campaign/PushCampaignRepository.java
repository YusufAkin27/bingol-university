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

    /** Yalnizca hala SCHEDULED/PAUSED ise iptal eder (yaris durumunda 0 doner). */
    @Transactional
    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE PushCampaign c SET c.status = edu.bingol.backend.notification.campaign.PushCampaign.Status.CANCELLED WHERE c.id = :id AND c.status IN (edu.bingol.backend.notification.campaign.PushCampaign.Status.SCHEDULED, edu.bingol.backend.notification.campaign.PushCampaign.Status.PAUSED)")
    int cancelIfScheduled(@Param("id") Long id);

    @Query("SELECT c FROM PushCampaign c WHERE c.status = :status AND (:cursor IS NULL OR c.id < :cursor) ORDER BY c.id DESC")
    List<PushCampaign> pageByStatus(@Param("status") PushCampaign.Status status, @Param("cursor") Long cursor,
                                    Pageable pageable);

    /** Yalnizca hala SCHEDULED ise duraklatir (zamani gelip SENDING olmus kampanya durdurulamaz). */
    @Transactional
    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE PushCampaign c SET c.status = edu.bingol.backend.notification.campaign.PushCampaign.Status.PAUSED WHERE c.id = :id AND c.status = edu.bingol.backend.notification.campaign.PushCampaign.Status.SCHEDULED")
    int pauseIfScheduled(@Param("id") Long id);

    @Transactional
    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE PushCampaign c SET c.status = edu.bingol.backend.notification.campaign.PushCampaign.Status.SCHEDULED WHERE c.id = :id AND c.status = edu.bingol.backend.notification.campaign.PushCampaign.Status.PAUSED")
    int resumeIfPaused(@Param("id") Long id);

    /** Ayni yoneticinin ayni icerik/kitleyle yakin zamanda olusturdugu (iptal/basarisiz olmayan) kampanya sayisi. */
    @Query("""
            SELECT COUNT(c) FROM PushCampaign c WHERE c.createdBy = :admin AND c.source = edu.bingol.backend.notification.campaign.PushCampaign.Source.CAMPAIGN
              AND c.titleTr = :title AND c.bodyTr = :body AND c.audienceType = :audType
              AND COALESCE(c.audienceValue, '') = :audValue
              AND c.createdAt > :since
              AND c.status NOT IN (edu.bingol.backend.notification.campaign.PushCampaign.Status.CANCELLED,
                                   edu.bingol.backend.notification.campaign.PushCampaign.Status.FAILED)
            """)
    long countRecentDuplicates(@Param("admin") Long admin, @Param("title") String title, @Param("body") String body,
                               @Param("audType") PushCampaign.AudienceType audType,
                               @Param("audValue") String audValue /* null yerine bos metin */, @Param("since") java.time.Instant since);
}
