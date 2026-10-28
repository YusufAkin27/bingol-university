package edu.bingol.backend.moderation;

import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ModerationStrikeRepository extends JpaRepository<ModerationStrike, Long>, JpaSpecificationExecutor<ModerationStrike> {

    java.util.List<ModerationStrike> findTop200ByUserIdOrderByIdDesc(Long userId);

    long countByUserIdAndRevokedAtIsNullAndCreatedAtAfter(Long userId, Instant since);

    long countByUserIdAndRevokedAtIsNull(Long userId);

    @Modifying
    @Query("UPDATE ModerationStrike s SET s.revokedAt = :now WHERE s.targetType = :type AND s.targetId = :id AND s.revokedAt IS NULL")
    int revokeForTarget(@Param("type") ReportTargetType type, @Param("id") Long id, @Param("now") Instant now);
}
