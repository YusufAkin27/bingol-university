package edu.bingol.backend.post.comment;

import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostCommentRepository extends JpaRepository<PostComment, Long> {

    /** Bakana gorunur yorum: silinmemis, gizlenmemis, yazar aktif, bakan ile arada engel yok. */
    String VISIBLE = "c.deletedAt IS NULL AND c.hiddenAt IS NULL "
            + "AND EXISTS (SELECT 1 FROM User u WHERE u.id = c.authorId AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE) "
            + "AND NOT EXISTS (SELECT 1 FROM UserBlock b WHERE (b.blockerId = :viewer AND b.blockedId = c.authorId) "
            + "OR (b.blockerId = c.authorId AND b.blockedId = :viewer)) ";

    String TOP_LEVEL = "SELECT c FROM PostComment c WHERE c.postId = :pid AND c.parentId IS NULL AND c.hiddenAt IS NULL "
            + "AND ((c.deletedAt IS NOT NULL AND c.replyCount > 0) OR (" + VISIBLE + ")) ";

    // --- ust duzey: yeni ---
    @Query(TOP_LEVEL + "ORDER BY c.id DESC")
    List<PostComment> newestFirst(@Param("pid") Long postId, @Param("viewer") Long viewer, Pageable page);

    @Query(TOP_LEVEL + "AND c.id < :cid ORDER BY c.id DESC")
    List<PostComment> newestAfter(@Param("pid") Long postId, @Param("viewer") Long viewer, @Param("cid") Long cid,
                                  Pageable page);

    // --- ust duzey: populer (begeni, sonra yeni) ---
    @Query(TOP_LEVEL + "ORDER BY c.likeCount DESC, c.id DESC")
    List<PostComment> topFirst(@Param("pid") Long postId, @Param("viewer") Long viewer, Pageable page);

    @Query(TOP_LEVEL + "AND (c.likeCount < :lk OR (c.likeCount = :lk AND c.id < :cid)) ORDER BY c.likeCount DESC, c.id DESC")
    List<PostComment> topAfter(@Param("pid") Long postId, @Param("viewer") Long viewer, @Param("lk") int likes,
                               @Param("cid") Long cid, Pageable page);

    // --- yanitlar: eskiden yeniye ---
    String REPLIES = "SELECT c FROM PostComment c WHERE c.parentId = :parent AND " + VISIBLE;

    @Query(REPLIES + "ORDER BY c.id ASC")
    List<PostComment> repliesFirst(@Param("parent") Long parent, @Param("viewer") Long viewer, Pageable page);

    @Query(REPLIES + "AND c.id > :cid ORDER BY c.id ASC")
    List<PostComment> repliesAfter(@Param("parent") Long parent, @Param("viewer") Long viewer, @Param("cid") Long cid,
                                   Pageable page);

    @Query("SELECT l.id.commentId FROM PostCommentLike l WHERE l.id.userId = :uid AND l.id.commentId IN :ids")
    List<Long> likedAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> commentIds);
}
