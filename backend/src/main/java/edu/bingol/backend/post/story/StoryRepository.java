package edu.bingol.backend.post.story;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StoryRepository extends JpaRepository<Story, Long> {

    /** Yazarin canli (silinmemis, gizlenmemis, suresi dolmamis) hikayeleri, eskiden yeniye. */
    @Query("SELECT s FROM Story s WHERE s.authorId = :author AND s.deletedAt IS NULL AND s.hiddenAt IS NULL "
            + "AND s.expiresAt > :now ORDER BY s.createdAt, s.id")
    List<Story> live(@Param("author") Long authorId, @Param("now") Instant now);

    @Query("SELECT s FROM Story s WHERE s.authorId = :author")
    List<Story> allOf(@Param("author") Long authorId);

    /** Temizlik: suresi `expiredBefore`dan once dolmus ya da `deletedBefore`dan once silinmis. */
    @Query("SELECT s FROM Story s WHERE s.expiresAt < :expiredBefore OR (s.deletedAt IS NOT NULL AND s.deletedAt < :deletedBefore) "
            + "ORDER BY s.id")
    List<Story> stale(@Param("expiredBefore") Instant expiredBefore, @Param("deletedBefore") Instant deletedBefore,
                      Pageable page);
}
