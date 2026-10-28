package edu.bingol.backend.post;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/** Keşfet "top" sıralaması ve puan işi sorguları (üst düzey arayüz; bean: postRankRepository). */
public interface PostRankRepository extends Repository<Post, Long> {

    String ORDER = "ORDER BY p.rankScore DESC, p.id DESC";

    @Query("SELECT p FROM Post p WHERE " + PostRepository.FEED_VISIBLE + ORDER)
    List<Post> topFirst(@Param("viewer") Long viewer, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + PostRepository.FEED_VISIBLE
            + "AND (p.rankScore < :sc OR (p.rankScore = :sc AND p.id < :cid)) " + ORDER)
    List<Post> topAfter(@Param("viewer") Long viewer, @Param("sc") double score, @Param("cid") Long cid, Pageable page);

    /** Yazar başına takipçi sayısı (tek sorgu): [userId, followerCount]. */
    @Query("SELECT f.userId, f.followerCount FROM FollowStats f WHERE f.userId IN :ids")
    List<Object[]> followers(@Param("ids") Collection<Long> authorIds);

    @Query("SELECT f.followerCount FROM FollowStats f WHERE f.userId = :id")
    List<Integer> followersOf(@Param("id") Long authorId);

    /** Gönderi başına verilen tarihten beri beğeni: [postId, count]. */
    @Query("SELECT l.id.postId, COUNT(l) FROM PostLike l WHERE l.id.postId IN :ids AND l.createdAt >= :since GROUP BY l.id.postId")
    List<Object[]> recentLikes(@Param("ids") Collection<Long> postIds, @Param("since") Instant since);

    /** Gönderi başına açık şikâyet: [targetId, count]. */
    @Query("SELECT r.targetId, COUNT(r) FROM Report r WHERE r.targetType = edu.bingol.backend.moderation.ReportTargetType.FEED_POST "
            + "AND r.status = edu.bingol.backend.moderation.Report.Status.OPEN AND r.targetId IN :ids GROUP BY r.targetId")
    List<Object[]> openReports(@Param("ids") Collection<Long> postIds);

    @Modifying
    @Query("UPDATE Post p SET p.rankScore = 0 WHERE p.createdAt < :since AND p.rankScore <> 0")
    int zeroOld(@Param("since") Instant since);
}
