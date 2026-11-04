package edu.bingol.backend.post.reels;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** İzleme geçmişi + öneri yardımcı sorguları (üst düzey arayüz; bean: postWatchRepository). */
public interface PostWatchRepository extends JpaRepository<PostWatch, PostWatchId> {

    @Query("SELECT w FROM PostWatch w WHERE w.id.userId = :uid AND w.id.postId IN :ids")
    List<PostWatch> ofUser(@Param("uid") Long userId, @Param("ids") Collection<Long> postIds);

    @Query("SELECT w.id.postId FROM PostWatch w WHERE w.id.userId = :uid AND w.notInterested = TRUE")
    List<Long> notInterestedIds(@Param("uid") Long userId);

    /** Verilen andan beri görülmüş (normal modda hariç tutulacak) videolar, en yeni önce. */
    @Query("SELECT w.id.postId FROM PostWatch w WHERE w.id.userId = :uid AND w.lastSeenAt >= :since AND w.impressions > 0 "
            + "ORDER BY w.lastSeenAt DESC")
    List<Long> seenSince(@Param("uid") Long userId, @Param("since") Instant since, Pageable page);

    /** Verilen kimliklerden video olanlar. */
    @Query("SELECT p.id FROM Post p WHERE p.id IN :ids AND p.kind = 'VIDEO'")
    List<Long> videoIds(@Param("ids") Collection<Long> ids);

    @Query("SELECT w FROM PostWatch w WHERE w.id.userId = :uid ORDER BY w.lastSeenAt DESC")
    List<PostWatch> recentOf(@Param("uid") Long userId, Pageable page);

    @Modifying
    @Query("DELETE FROM PostWatch w WHERE w.id.userId = :uid")
    int deleteByUser(@Param("uid") Long userId);

    @Modifying
    @Query("DELETE FROM PostWatch w WHERE w.lastSeenAt < :before")
    int deleteOlderThan(@Param("before") Instant before);

    /** Yazar başına, bu kullanıcının beğendiği gönderi sayısı: [authorId, count]. */
    @Query("SELECT p.authorId, COUNT(l) FROM PostLike l, Post p WHERE p.id = l.id.postId AND l.id.userId = :uid "
            + "AND p.authorId IN :authors GROUP BY p.authorId")
    List<Object[]> likedAuthorCounts(@Param("uid") Long userId, @Param("authors") Collection<Long> authorIds);

    /** Aday yazarlardan takip edilenler. */
    @Query("SELECT f.id.b FROM UserFollow f WHERE f.id.a = :uid AND f.id.b IN :authors")
    List<Long> followedAmong(@Param("uid") Long userId, @Param("authors") Collection<Long> authorIds);
}
