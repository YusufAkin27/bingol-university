package edu.bingol.backend.support.feedback;

import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface FeedbackRepository extends JpaRepository<Feedback, Long> {

    @Query("SELECT f FROM Feedback f WHERE f.userId = :uid AND (:cursor IS NULL OR f.id < :cursor) ORDER BY f.id DESC")
    List<Feedback> mine(@Param("uid") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    List<Feedback> findByUserIdOrderByIdDesc(Long userId);

    Page<Feedback> findByPublicVisibleTrue(Pageable pageable);

    @Query("""
            SELECT f FROM Feedback f
            WHERE (:status IS NULL OR f.status = :status)
              AND (:category IS NULL OR f.category = :category)
              AND (:cursor IS NULL OR f.id < :cursor)
            ORDER BY f.id DESC""")
    List<Feedback> admin(@Param("status") Feedback.Status status, @Param("category") Feedback.Category category,
                         @Param("cursor") Long cursor, Pageable pageable);

    long countByUserIdAndCreatedAtAfter(Long userId, java.time.Instant after);

    // --- oylar (atomik; ayni kullanici ayni oneriye bir kez oy verir) ---

    @Transactional
    @Modifying
    @Query(value = "INSERT INTO feedback_vote (feedback_id, user_id) VALUES (:fid, :uid) ON CONFLICT DO NOTHING",
            nativeQuery = true)
    int insertVote(@Param("fid") Long feedbackId, @Param("uid") Long userId);

    @Transactional
    @Modifying
    @Query(value = "DELETE FROM feedback_vote WHERE feedback_id = :fid AND user_id = :uid", nativeQuery = true)
    int deleteVote(@Param("fid") Long feedbackId, @Param("uid") Long userId);

    @Transactional
    @Modifying
    @Query("UPDATE Feedback f SET f.voteCount = f.voteCount + :delta WHERE f.id = :id")
    int addVotes(@Param("id") Long id, @Param("delta") int delta);

    @Query(value = "SELECT feedback_id FROM feedback_vote WHERE user_id = :uid AND feedback_id IN (:ids)",
            nativeQuery = true)
    List<Long> votedAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> ids);
}
