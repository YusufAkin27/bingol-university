package edu.bingol.backend.dbmaint.admin;

import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface DataPurgeLogRepository extends JpaRepository<DataPurgeLog, Long> {

    List<DataPurgeLog> findTop50ByOrderByIdDesc();

    /** Canli (son {@code since} icinde nabiz atan) calisan temizlik var mi. */
    @Query("SELECT COUNT(p) > 0 FROM DataPurgeLog p WHERE p.status = edu.bingol.backend.dbmaint.admin.DataPurgeLog.Status.RUNNING AND p.updatedAt >= :since")
    boolean existsLive(@Param("since") Instant since);

    /** Nabzi kesilmis (surec oldu) RUNNING kayitlari INTERRUPTED yapar. */
    @Modifying
    @Transactional
    @Query("UPDATE DataPurgeLog p SET p.status = edu.bingol.backend.dbmaint.admin.DataPurgeLog.Status.INTERRUPTED, p.finishedAt = :now,"
            + " p.error = 'Süreç kesildi (uygulama yeniden başlamış olabilir).'"
            + " WHERE p.status = edu.bingol.backend.dbmaint.admin.DataPurgeLog.Status.RUNNING AND p.updatedAt < :before")
    int markStale(@Param("before") Instant before, @Param("now") Instant now);
}
