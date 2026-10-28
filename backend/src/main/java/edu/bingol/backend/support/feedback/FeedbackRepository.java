package edu.bingol.backend.support.feedback;

import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface FeedbackRepository extends JpaRepository<Feedback, Long>, JpaSpecificationExecutor<Feedback> {

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

    // --- P12: silme/birlestirme (tasinabilir SQL: ON CONFLICT yok) ---

    /** Kaynak onerinin oylarini hedefe tasir (hedefte zaten oyu olan kullanicilar atlanir). */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = "INSERT INTO feedback_vote (feedback_id, user_id) SELECT CAST(:target AS BIGINT), v.user_id "
            + "FROM feedback_vote v WHERE v.feedback_id = :source AND NOT EXISTS "
            + "(SELECT 1 FROM feedback_vote x WHERE x.feedback_id = :target AND x.user_id = v.user_id)", nativeQuery = true)
    int moveVotes(@Param("source") Long source, @Param("target") Long target);

    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = "DELETE FROM feedback_vote WHERE feedback_id = :fid", nativeQuery = true)
    int deleteVotesOf(@Param("fid") Long feedbackId);

    /** vote_count'u gercek oy sayisindan yeniden hesaplar. */
    @Transactional
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = "UPDATE feedback SET vote_count = (SELECT COUNT(*) FROM feedback_vote WHERE feedback_id = :fid) "
            + "WHERE id = :fid", nativeQuery = true)
    int recountVotes(@Param("fid") Long feedbackId);

    @Query(value = "SELECT feedback_id FROM feedback_vote WHERE user_id = :uid AND feedback_id IN (:ids)",
            nativeQuery = true)
    List<Long> votedAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> ids);
}
