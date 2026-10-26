package edu.bingol.backend.moderation;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SuspendRecommendationRepository extends JpaRepository<SuspendRecommendation, Long> {

    boolean existsByUserIdAndStatus(Long userId, SuspendRecommendation.Status status);

    @Query("SELECT s FROM SuspendRecommendation s WHERE s.status = :status AND (:cursor IS NULL OR s.id > :cursor) ORDER BY s.id ASC")
    List<SuspendRecommendation> page(@Param("status") SuspendRecommendation.Status status, @Param("cursor") Long cursor,
                                     Pageable pageable);
}
