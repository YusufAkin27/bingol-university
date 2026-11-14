package edu.bingol.backend.academician;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcScanRequestRepository extends JpaRepository<AcScanRequest, Long> {

    Optional<AcScanRequest> findBySessionIdAndStudentId(Long sessionId, Long studentId);

    /** Bekleyenler, eski -> yeni. Indeks: ak1900_scanreq_status_idx. */
    @Query("SELECT r FROM AcScanRequest r WHERE r.sessionId = :s AND r.status = edu.bingol.backend.academician.AcScanRequest.Status.PENDING ORDER BY r.id")
    List<AcScanRequest> pending(@Param("s") Long sessionId, Pageable page);

    @Query("SELECT COUNT(r) FROM AcScanRequest r WHERE r.sessionId = :s AND r.status = edu.bingol.backend.academician.AcScanRequest.Status.PENDING")
    long countPending(@Param("s") Long sessionId);
}
