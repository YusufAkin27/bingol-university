package edu.bingol.backend.post.reel;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Reels (video gonderi) sorgulari (KS-BE2). Video gonderi = gorunur VIDEO medyasi olan gonderi; gorunurluk
 * {@link PostRepository#VISIBLE} ile ayni (silinmemis, gizli degil, yazar aktif, engel yok, gizli hesap kapisi).
 */
public interface ReelRepository extends JpaRepository<Post, Long> {

    String VIDEO = "AND EXISTS (SELECT 1 FROM PostMedia pm WHERE pm.postId = p.id AND pm.kind = 'VIDEO' AND pm.hiddenAt IS NULL) ";

    String BY_AUTHOR = "SELECT p FROM Post p WHERE p.authorId = :author AND " + PostRepository.VISIBLE + VIDEO;

    @Query(BY_AUTHOR + PostRepository.LATEST_ORDER)
    List<Post> byAuthorFirst(@Param("author") Long author, @Param("viewer") Long viewer, Pageable page);

    @Query(BY_AUTHOR + PostRepository.LATEST_AFTER + PostRepository.LATEST_ORDER)
    List<Post> byAuthorAfter(@Param("author") Long author, @Param("viewer") Long viewer, @Param("at") Instant at,
                             @Param("cid") Long cid, Pageable page);
}
