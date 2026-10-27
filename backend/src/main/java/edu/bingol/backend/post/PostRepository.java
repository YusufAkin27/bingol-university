package edu.bingol.backend.post;

import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostRepository extends JpaRepository<Post, Long> {

    /** Gorunur gonderi: silinmemis, gizlenmemis, yazar aktif ve bakan ile arada engel yok. */
    String VISIBLE = "p.deletedAt IS NULL AND p.hiddenAt IS NULL "
            + "AND EXISTS (SELECT 1 FROM User u WHERE u.id = p.authorId AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE) "
            + "AND NOT EXISTS (SELECT 1 FROM UserBlock b WHERE (b.blockerId = :viewer AND b.blockedId = p.authorId) "
            + "OR (b.blockerId = p.authorId AND b.blockedId = :viewer)) ";

    String LATEST_AFTER = "AND (p.createdAt < :at OR (p.createdAt = :at AND p.id < :cid)) ";
    String POPULAR_AFTER = "AND (p.score < :sc OR (p.score = :sc AND p.id < :cid)) ";
    String LATEST_ORDER = "ORDER BY p.createdAt DESC, p.id DESC";
    String POPULAR_ORDER = "ORDER BY p.score DESC, p.id DESC";

    // --- Akis: yeni ---
    @Query("SELECT p FROM Post p WHERE " + VISIBLE + LATEST_ORDER)
    List<Post> latestFirst(@Param("viewer") Long viewer, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> latestAfter(@Param("viewer") Long viewer, @Param("at") Instant at, @Param("cid") Long cid, Pageable page);

    // --- Akis: populer (son 7 gun) ---
    @Query("SELECT p FROM Post p WHERE p.createdAt >= :since AND " + VISIBLE + POPULAR_ORDER)
    List<Post> popularFirst(@Param("viewer") Long viewer, @Param("since") Instant since, Pageable page);

    @Query("SELECT p FROM Post p WHERE p.createdAt >= :since AND " + VISIBLE + POPULAR_AFTER + POPULAR_ORDER)
    List<Post> popularAfter(@Param("viewer") Long viewer, @Param("since") Instant since, @Param("sc") double sc,
                            @Param("cid") Long cid, Pageable page);

    // --- Yazara gore (profil / benim) ---
    @Query("SELECT p FROM Post p WHERE p.authorId = :author AND " + VISIBLE + LATEST_ORDER)
    List<Post> byAuthorFirst(@Param("author") Long author, @Param("viewer") Long viewer, Pageable page);

    @Query("SELECT p FROM Post p WHERE p.authorId = :author AND " + VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> byAuthorAfter(@Param("author") Long author, @Param("viewer") Long viewer, @Param("at") Instant at,
                             @Param("cid") Long cid, Pageable page);

    // --- Puan isi ---
    @Query("SELECT p FROM Post p WHERE p.createdAt >= :since AND p.deletedAt IS NULL AND p.id > :afterId ORDER BY p.id")
    List<Post> scoreBatch(@Param("since") Instant since, @Param("afterId") Long afterId, Pageable page);

    @Modifying
    @Query("UPDATE Post p SET p.score = 0 WHERE p.createdAt < :since AND p.score <> 0")
    int zeroOldScores(@Param("since") Instant since);
}
