package edu.bingol.backend.moderation.profanity;

import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProfanityHitLogRepository extends JpaRepository<ProfanityHitLog, Long> {

    @Query("SELECT h.entity, h.field, COUNT(h) FROM ProfanityHitLog h WHERE h.at >= :since "
            + "GROUP BY h.entity, h.field ORDER BY COUNT(h) DESC")
    List<Object[]> countsSince(@Param("since") Instant since);

    @Modifying
    @Query("DELETE FROM ProfanityHitLog h WHERE h.at < :cutoff")
    int deleteOlderThan(@Param("cutoff") Instant cutoff);
}
