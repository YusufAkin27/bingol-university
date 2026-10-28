package edu.bingol.backend.moderation;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ModerationTargetStateRepository extends JpaRepository<ModerationTargetState, Long>, JpaSpecificationExecutor<ModerationTargetState> {

    Optional<ModerationTargetState> findByTargetTypeAndTargetId(ReportTargetType type, Long targetId);

    @Modifying
    @Query("DELETE FROM ModerationTargetState s WHERE s.targetType = :type AND s.targetId = :id")
    void clear(@Param("type") ReportTargetType type, @Param("id") Long id);

    /**
     * Gizleme isareti (yarissiz upsert). Yonetici karari ('ADMIN') otomatik ('AUTO') isaretle EZILMEZ.
     * PostgreSQL'e ozel (ON CONFLICT): duman betigiyle dogrulanir.
     */
    @Modifying
    @Query(value = """
            INSERT INTO moderation_target_state (target_type, target_id, hidden_by, hidden_at, updated_at)
            VALUES (:type, :id, :by, now(), now())
            ON CONFLICT (target_type, target_id) DO UPDATE SET
              hidden_by = CASE WHEN moderation_target_state.hidden_by = 'ADMIN' THEN 'ADMIN' ELSE EXCLUDED.hidden_by END,
              hidden_at = COALESCE(moderation_target_state.hidden_at, EXCLUDED.hidden_at),
              updated_at = now()
            """, nativeQuery = true)
    void markHidden(@Param("type") String type, @Param("id") Long id, @Param("by") String by);
}
