package edu.bingol.backend.mail.admin;

import edu.bingol.backend.mail.MailOutbox;
import edu.bingol.backend.mail.MailStatus;
import java.time.Instant;
import java.util.Collection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici kuyruk gorunumu (P13). Durum gecisleri TEK ATOMIK UPDATE'tir (kosul: beklenen durum): isleyici ayni kaydi
 * gonderirken yonetici kosulu bozamaz, ikisi birden uygulanmaz.
 */
public interface MailOutboxQueryRepository extends JpaRepository<MailOutbox, Long>, JpaSpecificationExecutor<MailOutbox> {

    /** DEAD/SKIPPED -> PENDING (hemen). Donen 0 = durum degismisti. */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE MailOutbox m SET m.status = edu.bingol.backend.mail.MailStatus.PENDING, m.attempts = 0, "
            + "m.nextAttemptAt = :now, m.lastError = NULL WHERE m.id = :id AND m.status IN (:from)")
    int requeue(@Param("id") Long id, @Param("from") Collection<MailStatus> from, @Param("now") Instant now);

    /** PENDING/FAILED -> SKIPPED (iptal); degiskenler temizlenir. */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE MailOutbox m SET m.status = edu.bingol.backend.mail.MailStatus.SKIPPED, m.lastError = :note, "
            + "m.varsJson = '{}' WHERE m.id = :id AND m.status IN (:from)")
    int cancel(@Param("id") Long id, @Param("from") Collection<MailStatus> from, @Param("note") String note);

    long countByStatus(MailStatus status);

    @Query("SELECT MIN(m.createdAt) FROM MailOutbox m WHERE m.status IN :st")
    Instant oldestCreated(@Param("st") Collection<MailStatus> st);
}
