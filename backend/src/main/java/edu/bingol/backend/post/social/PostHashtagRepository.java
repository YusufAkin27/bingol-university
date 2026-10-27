package edu.bingol.backend.post.social;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostHashtagRepository extends JpaRepository<PostHashtag, PairId> {

    @Query("SELECT h.id.b FROM PostHashtag h WHERE h.id.a = :post")
    List<Long> hashtagIdsOf(@Param("post") Long postId);

    /** [postId, display] ciftleri. */
    @Query("SELECT l.id.a, t.display FROM PostHashtag l, Hashtag t WHERE t.id = l.id.b AND l.id.a IN :posts "
            + "ORDER BY l.createdAt, t.id")
    List<Object[]> displaysOf(@Param("posts") Collection<Long> postIds);
}
