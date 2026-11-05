package edu.bingol.backend.forum.moderation;

import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumModerationActionRepository extends JpaRepository<ForumModerationActionRecord, Long> {

    @Query("SELECT a FROM ForumModerationActionRecord a WHERE (:type IS NULL OR a.targetType = :type) "
            + "AND (:action IS NULL OR a.action = :action) ORDER BY a.createdAt DESC, a.id DESC")
    Slice<ForumModerationActionRecord> list(@Param("type") String type, @Param("action") String action, Pageable pageable);
}
