package edu.bingol.backend.academician;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AcademicianRepository extends JpaRepository<Academician, Long> {

    /** Es zamanli onay/ret kararlari tek satirda siralansin. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM Academician a WHERE a.userId = :id")
    Optional<Academician> lockById(@Param("id") Long id);

    /** Yonetici listesi (userId'ye gore azalan imec). Indeks: ak1900_academician_status_idx. */
    @Query("SELECT a FROM Academician a WHERE a.status IN :statuses AND a.userId < :before ORDER BY a.userId DESC")
    List<Academician> page(@Param("statuses") Collection<Academician.Status> statuses, @Param("before") Long before,
                           Pageable page);

    @Query("SELECT a FROM Academician a WHERE a.status IN :statuses AND a.approvalMode = :mode AND a.userId < :before "
            + "ORDER BY a.userId DESC")
    List<Academician> pageByMode(@Param("statuses") Collection<Academician.Status> statuses,
                                 @Param("mode") Academician.ApprovalMode mode, @Param("before") Long before, Pageable page);
}
