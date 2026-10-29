package edu.bingol.backend.mail;

import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface MailOutboxRepository extends JpaRepository<MailOutbox, Long> {

    /**
     * Zamani gelen e-postalari atomik olarak "kiralar": next_attempt_at ileri alinir, boylece baska sunucu
     * ayni kaydi almaz; sunucu cokerse kira bitince kayit yeniden denenir. SKIP LOCKED cok sunucu guvenlidir.
     * YALNIZ islemsel (priority=0) kayitlar; duyurular {@link #claimDueAnnouncements} ile hiz sinirli alinir.
     */
    @Transactional
    @Query(value = """
            UPDATE mail_outbox SET next_attempt_at = :leaseUntil
            WHERE id IN (SELECT id FROM mail_outbox
                         WHERE status IN ('PENDING', 'FAILED') AND priority = 0 AND next_attempt_at <= :now
                         ORDER BY next_attempt_at, id LIMIT :batch FOR UPDATE SKIP LOCKED)
            RETURNING id
            """, nativeQuery = true)
    List<Long> claimDue(@Param("now") Instant now, @Param("leaseUntil") Instant leaseUntil,
                        @Param("batch") int batch);

    /** Duyuru (priority=1) kayitlari icin {@link #claimDue}: ayri alinir ki hiz siniri butcesi kadar kiralansin. */
    @Transactional
    @Query(value = """
            UPDATE mail_outbox SET next_attempt_at = :leaseUntil
            WHERE id IN (SELECT id FROM mail_outbox
                         WHERE status IN ('PENDING', 'FAILED') AND priority > 0 AND next_attempt_at <= :now
                         ORDER BY next_attempt_at, id LIMIT :batch FOR UPDATE SKIP LOCKED)
            RETURNING id
            """, nativeQuery = true)
    List<Long> claimDueAnnouncements(@Param("now") Instant now, @Param("leaseUntil") Instant leaseUntil,
                                     @Param("batch") int batch);

    /** Son dakikada gonderilen duyuru sayisi (hiz siniri butcesi; cok ornekte ortak). */
    long countByPriorityGreaterThanAndStatusAndSentAtAfter(int priority, MailStatus status, Instant after);

    /** Bu adrese yakin zamanda duyuru gonderildi mi (ayni aliciya tekrar siniri). */
    boolean existsByToAddressAndPriorityGreaterThanAndStatusAndSentAtAfter(String toAddress, int priority,
                                                                          MailStatus status, Instant after);

    long countByStatus(MailStatus status);

    /** Temizlik: belirtilen tarihten eski her durumdaki kayit (takilmis PENDING/FAILED dahil; kisisel veri tutmamak icin). */
    @Transactional
    @Modifying
    @Query("DELETE FROM MailOutbox m WHERE m.createdAt < :before")
    int deleteFinishedBefore(@Param("before") Instant before);

    long countByStatusAndSentAtAfter(MailStatus status, Instant after);

    /** Bekleyen (PENDING/FAILED) en eski kayit zamani; yoksa null. */
    @Query("SELECT MIN(m.createdAt) FROM MailOutbox m WHERE m.status IN (edu.bingol.backend.mail.MailStatus.PENDING, edu.bingol.backend.mail.MailStatus.FAILED)")
    Instant oldestPendingCreatedAt();

    /**
     * Yonetici: olu (DEAD) kayitlari yeniden kuyruga alir. DEAD olurken degiskenler temizlendigi ({}) icin icerigi
     * yeniden uretilemeyen kayitlar (ACCOUNT_DELETED haric) ve suresi dolmus kod postalari ({@code codeCutoff}'tan
     * eski) ALINMAZ; bos degiskenle bos/kodsuz posta gitmesin diye.
     */
    @Transactional
    @Modifying
    @Query("UPDATE MailOutbox m SET m.status = edu.bingol.backend.mail.MailStatus.PENDING, m.attempts = 0, "
            + "m.nextAttemptAt = :now WHERE m.status = edu.bingol.backend.mail.MailStatus.DEAD "
            + "AND (m.template = edu.bingol.backend.mail.MailTemplate.ACCOUNT_DELETED "
            + "OR (m.varsJson IS NOT NULL AND TRIM(m.varsJson) <> '' AND TRIM(m.varsJson) <> '{}')) "
            + "AND NOT (m.template IN (edu.bingol.backend.mail.MailTemplate.VERIFICATION_CODE, "
            + "edu.bingol.backend.mail.MailTemplate.PASSWORD_RESET_CODE) AND m.createdAt < :codeCutoff)")
    int requeueDead(@Param("now") Instant now, @Param("codeCutoff") Instant codeCutoff);
}
