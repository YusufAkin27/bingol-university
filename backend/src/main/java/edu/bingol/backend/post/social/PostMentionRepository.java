package edu.bingol.backend.post.social;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostMentionRepository extends JpaRepository<PostMention, Long> {

    @Query("SELECT m FROM PostMention m WHERE m.postId = :post AND m.commentId IS NULL")
    List<PostMention> ofPost(@Param("post") Long postId);

    List<PostMention> findByCommentId(Long commentId);

    @Query("SELECT m FROM PostMention m WHERE m.commentId IS NULL AND m.postId IN :ids")
    List<PostMention> ofPosts(@Param("ids") Collection<Long> postIds);

    @Query("SELECT m FROM PostMention m WHERE m.commentId IN :ids")
    List<PostMention> ofComments(@Param("ids") Collection<Long> commentIds);
}
