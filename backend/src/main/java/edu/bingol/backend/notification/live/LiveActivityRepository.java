package edu.bingol.backend.notification.live;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LiveActivityRepository extends JpaRepository<LiveActivity, Long> {

    Optional<LiveActivity> findByUserIdAndActivityId(Long userId, String activityId);

    @Query("SELECT COUNT(a) FROM LiveActivity a WHERE a.userId = :uid AND a.endedAt IS NULL AND a.expiresAt > :now")
    long countActive(@Param("uid") Long userId, @Param("now") Instant now);

    @Query("SELECT a FROM LiveActivity a WHERE a.kind = :kind AND a.refId = :ref AND a.endedAt IS NULL "
            + "AND a.expiresAt > :now AND a.pushToken IS NOT NULL")
    List<LiveActivity> activeForRef(@Param("kind") LiveActivity.Kind kind, @Param("ref") Long refId,
                                    @Param("now") Instant now);

    @Modifying
    @Query("DELETE FROM LiveActivity a WHERE a.expiresAt < :cutoff OR (a.endedAt IS NOT NULL AND a.endedAt < :cutoff)")
    int deleteOld(@Param("cutoff") Instant cutoff);
}
