package edu.bingol.backend.moderation;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ReportRepository extends JpaRepository<Report, Long> {

    boolean existsByReporterIdAndTargetTypeAndTargetIdAndStatus(Long reporterId, ReportTargetType type, Long targetId,
                                                                Report.Status status);

    long countByStatus(Report.Status status);

    @Query("SELECT r FROM Report r WHERE r.status = :status AND (:cursor IS NULL OR r.id > :cursor) ORDER BY r.id ASC")
    List<Report> queue(@Param("status") Report.Status status, @Param("cursor") Long cursor, Pageable pageable);

    /** Ayni hedefe bekleyen diger raporlar (tek karar hepsini kapatir). */
    List<Report> findByTargetTypeAndTargetIdAndStatus(ReportTargetType type, Long targetId, Report.Status status);
}
