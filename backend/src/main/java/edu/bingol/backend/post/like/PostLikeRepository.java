package edu.bingol.backend.post.like;

import edu.bingol.backend.post.PostRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostLikeRepository extends JpaRepository<PostLike, PostLikeId> {

    /** Bakana gorunur gonderinin yazari (gizli/silinmis/engelli ise bos). */
    @Query("SELECT p.authorId FROM Post p WHERE p.id = :pid AND " + PostRepository.VISIBLE)
    Optional<Long> visibleAuthor(@Param("pid") Long postId, @Param("viewer") Long viewer);

    @Modifying
    @Query("DELETE FROM PostLike l WHERE l.id.postId = :pid AND l.id.userId = :uid")
    int deleteLike(@Param("pid") Long postId, @Param("uid") Long userId);

    @Query("SELECT l.id.postId FROM PostLike l WHERE l.id.userId = :uid AND l.id.postId IN :ids")
    List<Long> likedAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> postIds);

    String LIKERS = "FROM PostLike l, User u WHERE u.id = l.id.userId AND l.id.postId = :pid "
            + "AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE AND l.id.userId NOT IN :hidden ";

    @Query("SELECT l " + LIKERS + "ORDER BY l.createdAt DESC, l.id.userId DESC")
    List<PostLike> likersFirst(@Param("pid") Long postId, @Param("hidden") Collection<Long> hidden, Pageable page);

    @Query("SELECT l " + LIKERS + "AND (l.createdAt < :at OR (l.createdAt = :at AND l.id.userId < :uid)) "
            + "ORDER BY l.createdAt DESC, l.id.userId DESC")
    List<PostLike> likersAfter(@Param("pid") Long postId, @Param("hidden") Collection<Long> hidden,
                               @Param("at") Instant at, @Param("uid") Long uid, Pageable page);

    @Query("SELECT COUNT(l) " + LIKERS)
    long countLikers(@Param("pid") Long postId, @Param("hidden") Collection<Long> hidden);
}
