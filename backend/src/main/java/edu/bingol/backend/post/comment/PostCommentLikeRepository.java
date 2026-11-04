package edu.bingol.backend.post.comment;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostCommentLikeRepository extends JpaRepository<PostCommentLike, PostCommentLikeId> {

    @Modifying
    @Query("DELETE FROM PostCommentLike l WHERE l.id.commentId = :cid AND l.id.userId = :uid")
    int deleteLike(@Param("cid") Long commentId, @Param("uid") Long userId);
}
