package edu.bingol.backend.notification.outbox;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface PushOutboxRepository extends JpaRepository<PushOutbox, Long> {

    /**
     * Zamani gelen kayitlari atomik "kiralar" (SENDING + lease_until). Kirasi dolmus SENDING kayitlari da
     * (cokmus sunucudan kalanlar) yeniden alinir. SKIP LOCKED cok sunucu guvenlidir (yalniz PostgreSQL).
     */
    @Transactional
    @Query(value = """
            UPDATE push_outbox SET status = 'SENDING', lease_until = :leaseUntil
            WHERE id IN (SELECT id FROM push_outbox
                         WHERE (status IN ('PENDING', 'FAILED') AND next_attempt_at <= :now)
                            OR (status = 'SENDING' AND lease_until < :now)
                         ORDER BY priority DESC, next_attempt_at, id LIMIT :batch FOR UPDATE SKIP LOCKED)
            RETURNING id
            """, nativeQuery = true)
    List<Long> claimDue(@Param("now") Instant now, @Param("leaseUntil") Instant leaseUntil, @Param("batch") int batch);

    /** Acilista: kirasi dolmus SENDING kayitlarini PENDING'e geri alir. */
    @Transactional
    @Modifying
    @Query("UPDATE PushOutbox o SET o.status = edu.bingol.backend.notification.outbox.PushOutboxStatus.PENDING, "
            + "o.leaseUntil = NULL WHERE o.status = edu.bingol.backend.notification.outbox.PushOutboxStatus.SENDING "
            + "AND (o.leaseUntil IS NULL OR o.leaseUntil < :now)")
    int recoverStale(@Param("now") Instant now);

    /** Her cihaz icin en son kuyruk kaydi (yonetici teshisi: kullanici cihazlari). */
    @Query("SELECT o FROM PushOutbox o WHERE o.id IN (SELECT MAX(o2.id) FROM PushOutbox o2 "
            + "WHERE o2.deviceId IN :ids GROUP BY o2.deviceId)")
    List<PushOutbox> latestForDevices(@Param("ids") Collection<Long> deviceIds);

    long countByStatus(PushOutboxStatus status);

    long countByStatusAndSentAtAfter(PushOutboxStatus status, Instant after);

    @Query("SELECT MIN(o.createdAt) FROM PushOutbox o WHERE o.status IN "
            + "(edu.bingol.backend.notification.outbox.PushOutboxStatus.PENDING, "
            + "edu.bingol.backend.notification.outbox.PushOutboxStatus.FAILED)")
    Instant oldestPendingAt();

    @Query("SELECT COUNT(o) > 0 FROM PushOutbox o WHERE o.dedupeKey = :key AND o.deviceId = :deviceId AND o.status IN "
            + "(edu.bingol.backend.notification.outbox.PushOutboxStatus.PENDING, "
            + "edu.bingol.backend.notification.outbox.PushOutboxStatus.SENDING, "
            + "edu.bingol.backend.notification.outbox.PushOutboxStatus.FAILED)")
    boolean existsActive(@Param("key") String dedupeKey, @Param("deviceId") Long deviceId);

    @Transactional
    @Modifying
    @Query("UPDATE PushOutbox o SET o.status = edu.bingol.backend.notification.outbox.PushOutboxStatus.PENDING, "
            + "o.attempts = 0, o.nextAttemptAt = :now, o.leaseUntil = NULL "
            + "WHERE o.status = edu.bingol.backend.notification.outbox.PushOutboxStatus.DEAD")
    int requeueDead(@Param("now") Instant now);

    @Transactional
    @Modifying
    @Query("DELETE FROM PushOutbox o WHERE o.status = :status AND o.createdAt < :before")
    int deleteByStatusBefore(@Param("status") PushOutboxStatus status, @Param("before") Instant before);

    @Transactional
    @Modifying
    @Query("DELETE FROM PushOutbox o WHERE o.status IN :statuses AND o.createdAt < :before")
    int deleteByStatusInBefore(@Param("statuses") Collection<PushOutboxStatus> statuses, @Param("before") Instant before);

    /** Hesap silinince kullanicinin bekleyen push'lari da silinir. */
    @Transactional
    @Modifying
    @Query("DELETE FROM PushOutbox o WHERE o.userId = :userId")
    int deleteByUser(@Param("userId") Long userId);
}
