package edu.bingol.backend.accessban;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface BlockedAttemptLogRepository extends JpaRepository<BlockedAttemptLog, Long> {

    List<BlockedAttemptLog> findByBanIdOrderByIdDesc(Long banId, Pageable page);

    List<BlockedAttemptLog> findByBanIdAndIdLessThanOrderByIdDesc(Long banId, Long cursor, Pageable page);

    long countByAttemptedAtAfter(Instant since);

    @Transactional
    @Modifying
    @Query("DELETE FROM BlockedAttemptLog l WHERE l.attemptedAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") Instant cutoff);
}
