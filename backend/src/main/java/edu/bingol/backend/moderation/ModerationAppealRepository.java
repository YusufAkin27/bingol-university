package edu.bingol.backend.moderation;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ModerationAppealRepository extends JpaRepository<ModerationAppeal, Long> {

    /** Bu gizleme olayindan sonra ayni kullanici ayni hedef icin zaten itiraz acti mi (karar verilmis olsa da). */
    boolean existsByUserIdAndTargetTypeAndTargetIdAndCreatedAtAfter(Long userId, ReportTargetType type, Long targetId,
                                                                    Instant since);

    List<ModerationAppeal> findTop50ByUserIdOrderByIdDesc(Long userId);

    @Query("SELECT a FROM ModerationAppeal a WHERE a.status = :status AND (:cursor IS NULL OR a.id > :cursor) ORDER BY a.id ASC")
    List<ModerationAppeal> page(@Param("status") ModerationAppeal.Status status, @Param("cursor") Long cursor,
                                Pageable pageable);
}
