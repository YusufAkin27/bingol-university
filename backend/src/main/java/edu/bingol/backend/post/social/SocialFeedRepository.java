package edu.bingol.backend.post.social;

import static edu.bingol.backend.post.PostRepository.LATEST_AFTER;
import static edu.bingol.backend.post.PostRepository.LATEST_ORDER;
import static edu.bingol.backend.post.PostRepository.VISIBLE;

import edu.bingol.backend.post.Post;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;

/** Akis kapsamlari (takip, bolum, etiket): "yeni -> eski" imleci (createdAt, id) ve PostRepository.VISIBLE kurali. */
public interface SocialFeedRepository extends Repository<Post, Long> {

    String FOLLOWING = "(p.authorId = :viewer OR EXISTS (SELECT 1 FROM UserFollow f WHERE f.id.a = :viewer "
            + "AND f.id.b = p.authorId)) AND ";
    String DEPARTMENT = "p.authorId IN (SELECT u.id FROM User u WHERE u.department = :dept) AND ";
    String HASHTAG = "EXISTS (SELECT 1 FROM PostHashtag h WHERE h.id.a = p.id AND h.id.b = :tag) AND ";

    @Query("SELECT p FROM Post p WHERE " + FOLLOWING + VISIBLE + LATEST_ORDER)
    List<Post> followingFirst(@Param("viewer") Long viewer, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + FOLLOWING + VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> followingAfter(@Param("viewer") Long viewer, @Param("at") Instant at, @Param("cid") Long cid,
                              Pageable page);

    @Query("SELECT p FROM Post p WHERE " + DEPARTMENT + VISIBLE + LATEST_ORDER)
    List<Post> departmentFirst(@Param("viewer") Long viewer, @Param("dept") String dept, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + DEPARTMENT + VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> departmentAfter(@Param("viewer") Long viewer, @Param("dept") String dept, @Param("at") Instant at,
                               @Param("cid") Long cid, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + HASHTAG + VISIBLE + LATEST_ORDER)
    List<Post> hashtagFirst(@Param("viewer") Long viewer, @Param("tag") Long tagId, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + HASHTAG + VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> hashtagAfter(@Param("viewer") Long viewer, @Param("tag") Long tagId, @Param("at") Instant at,
                            @Param("cid") Long cid, Pageable page);
}
