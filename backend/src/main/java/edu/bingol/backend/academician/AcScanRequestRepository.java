package edu.bingol.backend.academician;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface AcScanRequestRepository extends JpaRepository<AcScanRequest, Long> {

    Optional<AcScanRequest> findBySessionIdAndStudentId(Long sessionId, Long studentId);

    /** KVKK disa aktarim: ogrencinin kendi istekleri. */
    @Query("SELECT r FROM AcScanRequest r WHERE r.studentId = :s ORDER BY r.id")
    List<AcScanRequest> ofStudent(@Param("s") Long studentId, Pageable page);

    /** Bekleyenler, eski -> yeni. Indeks: ak1900_scanreq_status_idx. */
    @Query("SELECT r FROM AcScanRequest r WHERE r.sessionId = :s AND r.status = edu.bingol.backend.academician.AcScanRequest.Status.PENDING ORDER BY r.id")
    List<AcScanRequest> pending(@Param("s") Long sessionId, Pageable page);

    @Modifying
    @Transactional
    @Query("DELETE FROM AcScanRequest r WHERE r.sessionId = :s")
    int deleteOfSession(@Param("s") Long sessionId);

    /** Oturum listesi icin: [oturum, bekleyen sayisi]. */
    @Query("SELECT r.sessionId, COUNT(r) FROM AcScanRequest r WHERE r.sessionId IN :ids AND r.status = "
            + "edu.bingol.backend.academician.AcScanRequest.Status.PENDING GROUP BY r.sessionId")
    List<Object[]> pendingCounts(@Param("ids") java.util.Collection<Long> sessionIds);

    @Query("SELECT COUNT(r) FROM AcScanRequest r WHERE r.sessionId = :s AND r.status = edu.bingol.backend.academician.AcScanRequest.Status.PENDING")
    long countPending(@Param("s") Long sessionId);
}
