package edu.bingol.backend.post;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostRepository extends JpaRepository<Post, Long> {

    /** Idempotency-Key ile onceden olusturulmus gonderi (silinmis olsa da satir doner). */
    java.util.Optional<Post> findFirstByAuthorIdAndIdempotencyKey(Long authorId, String idempotencyKey);

    /** Gorunur gonderi: silinmemis, gizlenmemis, yazar aktif ve bakan ile arada engel yok. */
    String VISIBLE = "p.deletedAt IS NULL AND p.hiddenAt IS NULL "
            + "AND EXISTS (SELECT 1 FROM User u WHERE u.id = p.authorId AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE) "
            + "AND NOT EXISTS (SELECT 1 FROM UserBlock b WHERE (b.blockerId = :viewer AND b.blockedId = p.authorId) "
            + "OR (b.blockerId = p.authorId AND b.blockedId = :viewer)) "
            // Gizli hesap (V1020): gonderi yalniz yazarin kendisine ve KABUL EDILMIS takipcilerine gorunur. Satiri olmayan
            // yazar herkese aciktir (NOT EXISTS ... = TRUE); bekleyen istek (follow_request) gorunurluk vermez.
            + "AND (p.authorId = :viewer OR NOT EXISTS (SELECT 1 FROM ProfilePrivacy pp WHERE pp.userId = p.authorId "
            + "AND pp.privateAccount = TRUE) OR EXISTS (SELECT 1 FROM UserFollow uf WHERE uf.id.a = :viewer "
            + "AND uf.id.b = p.authorId)) ";

    /** Kesfet: gorunur bir medyasi (fotograf ya da video) olan gonderiler akista listelenir (medyasiz metin-only eskiler gizli; veri silinmez). */
    String MEDIA = "AND EXISTS (SELECT 1 FROM PostMedia pm WHERE pm.postId = p.id AND pm.hiddenAt IS NULL) ";
    String FEED_VISIBLE = VISIBLE + MEDIA;

    String LATEST_AFTER = "AND (p.createdAt < :at OR (p.createdAt = :at AND p.id < :cid)) ";
    String POPULAR_AFTER = "AND (p.score < :sc OR (p.score = :sc AND p.id < :cid)) ";
    String LATEST_ORDER = "ORDER BY p.createdAt DESC, p.id DESC";
    String POPULAR_ORDER = "ORDER BY p.score DESC, p.id DESC";

    // --- Akis: yeni ---
    @Query("SELECT p FROM Post p WHERE " + FEED_VISIBLE + LATEST_ORDER)
    List<Post> latestFirst(@Param("viewer") Long viewer, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + FEED_VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> latestAfter(@Param("viewer") Long viewer, @Param("at") Instant at, @Param("cid") Long cid, Pageable page);

    // --- Akis: populer (son 7 gun) ---
    @Query("SELECT p FROM Post p WHERE p.createdAt >= :since AND " + FEED_VISIBLE + POPULAR_ORDER)
    List<Post> popularFirst(@Param("viewer") Long viewer, @Param("since") Instant since, Pageable page);

    @Query("SELECT p FROM Post p WHERE p.createdAt >= :since AND " + FEED_VISIBLE + POPULAR_AFTER + POPULAR_ORDER)
    List<Post> popularAfter(@Param("viewer") Long viewer, @Param("since") Instant since, @Param("sc") double sc,
                            @Param("cid") Long cid, Pageable page);

    // --- Yazara gore (profil / benim) ---
    @Query("SELECT p FROM Post p WHERE p.authorId = :author AND " + FEED_VISIBLE + LATEST_ORDER)
    List<Post> byAuthorFirst(@Param("author") Long author, @Param("viewer") Long viewer, Pageable page);

    @Query("SELECT p FROM Post p WHERE p.authorId = :author AND " + FEED_VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> byAuthorAfter(@Param("author") Long author, @Param("viewer") Long viewer, @Param("at") Instant at,
                             @Param("cid") Long cid, Pageable page);

    // --- Puan isi ---
    @Query("SELECT p FROM Post p WHERE p.createdAt >= :since AND p.deletedAt IS NULL AND p.id > :afterId ORDER BY p.id")
    List<Post> scoreBatch(@Param("since") Instant since, @Param("afterId") Long afterId, Pageable page);

    @Modifying
    @Query("UPDATE Post p SET p.score = 0 WHERE p.createdAt < :since AND p.score <> 0")
    int zeroOldScores(@Param("since") Instant since);
}
