package edu.bingol.backend.moderation;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ReportRepository extends JpaRepository<Report, Long>, JpaSpecificationExecutor<Report> {

    boolean existsByReporterIdAndTargetTypeAndTargetIdAndStatus(Long reporterId, ReportTargetType type, Long targetId,
                                                                Report.Status status);

    /** Ayni kisinin ayni hedefe verdigi yakin tarihli (herhangi durumda) rapor var mi. */
    boolean existsByReporterIdAndTargetTypeAndTargetIdAndCreatedAtAfter(Long reporterId, ReportTargetType type,
                                                                        Long targetId, Instant since);

    long countByStatus(Report.Status status);

    @Query("SELECT r FROM Report r WHERE r.status = :status AND (:type IS NULL OR r.targetType = :type) AND (:cursor IS NULL OR r.id > :cursor) ORDER BY r.id ASC")
    List<Report> queue(@Param("status") Report.Status status, @Param("type") ReportTargetType type,
                       @Param("cursor") Long cursor, Pageable pageable);

    /** Yeniden eskiye (imec: id kucukse). */
    @Query("SELECT r FROM Report r WHERE r.status = :status AND (:type IS NULL OR r.targetType = :type) AND (:cursor IS NULL OR r.id < :cursor) ORDER BY r.id DESC")
    List<Report> queueNewestFirst(@Param("status") Report.Status status, @Param("type") ReportTargetType type,
                                  @Param("cursor") Long cursor, Pageable pageable);

    /** Oncelik sirasi (yuksekten dusuge, esitlikte eskiden yeniye); sayfa numarasi tabanli (Slice). */
    @Query("SELECT r FROM Report r WHERE r.status = :status AND (:type IS NULL OR r.targetType = :type) ORDER BY r.priority DESC, r.id ASC")
    Slice<Report> queueByPriority(@Param("status") Report.Status status, @Param("type") ReportTargetType type,
                                  Pageable pageable);

    /** Ayni hedefe bekleyen diger raporlar (tek karar hepsini kapatir). */
    List<Report> findByTargetTypeAndTargetIdAndStatus(ReportTargetType type, Long targetId, Report.Status status);

    @Query("SELECT COUNT(DISTINCT r.reporterId) FROM Report r WHERE r.targetType = :type AND r.targetId = :id AND r.status = edu.bingol.backend.moderation.Report.Status.OPEN")
    long countOpenReporters(@Param("type") ReportTargetType type, @Param("id") Long id);

    /** Esige sayilan raporlayicilar: yalnizca belirli yastan eski hesaplar (sahte hesap istismarina karsi). */
    @Query("SELECT COUNT(DISTINCT r.reporterId) FROM Report r WHERE r.targetType = :type AND r.targetId = :id "
            + "AND r.status = edu.bingol.backend.moderation.Report.Status.OPEN "
            + "AND r.reporterId IN (SELECT u.id FROM User u WHERE u.createdAt <= :cutoff)")
    long countEligibleOpenReporters(@Param("type") ReportTargetType type, @Param("id") Long id,
                                    @Param("cutoff") Instant cutoff);

    @Modifying
    @Query("UPDATE Report r SET r.priority = :p WHERE r.targetType = :type AND r.targetId = :id AND r.status = edu.bingol.backend.moderation.Report.Status.OPEN")
    int updateOpenPriority(@Param("type") ReportTargetType type, @Param("id") Long id, @Param("p") int priority);

    /** Raporlayanin pencere icinde reddedilen (DISMISS) rapor sayisi. */
    long countByReporterIdAndResolutionAndResolvedAtAfter(Long reporterId, Report.Resolution resolution, Instant since);

    List<Report> findTop200ByReporterIdOrderByIdDesc(Long reporterId);
}
