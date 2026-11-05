package edu.bingol.backend.forum.topic;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Konu sorgulari. Gorunurluk ortak kosulu: silinmemis + ACTIVE + yazari ACTIVE hesap (kendi konusu her durumda
 * kendisine kalir). Gizlenecek yazarlar (engel/sessize) {@code hidden} kumesiyle disarida birakilir; bos kume
 * yerine {@code -1} verilir (bos IN listesi tasinabilir degildir). Tum liste sorgulari sayfalidir (Pageable).
 */
public interface ForumTopicRepository extends JpaRepository<ForumTopic, Long> {

    String VISIBLE = "t.deletedAt IS NULL AND t.status = 'ACTIVE' AND t.userId NOT IN :hidden "
            + "AND (t.userId = :viewer OR EXISTS (SELECT 1 FROM User u WHERE u.id = t.userId AND u.status = "
            + "edu.bingol.backend.user.UserStatus.ACTIVE))";

    Optional<ForumTopic> findByIdAndDeletedAtIsNull(Long id);

    Optional<ForumTopic> findByUserIdAndIdemKey(Long userId, String idemKey);

    /** Gorunur tek konu. */
    @Query("SELECT t FROM ForumTopic t WHERE t.id = :id AND " + VISIBLE)
    Optional<ForumTopic> findVisible(@Param("id") Long id, @Param("viewer") Long viewer,
                                     @Param("hidden") Collection<Long> hidden);

    /** Verilen kimliklerden gorunur olanlar (sira cagirandadir). */
    @Query("SELECT t FROM ForumTopic t WHERE t.id IN :ids AND " + VISIBLE)
    List<ForumTopic> findVisibleByIds(@Param("ids") Collection<Long> ids, @Param("viewer") Long viewer,
                                      @Param("hidden") Collection<Long> hidden);

    // ------------------------------------------------------------------ akis (sabitlenmisler cagiranda ayri)

    /** NEWEST: id azalan (id kimlik sutunu, olusturma sirasiyla artar); kategori 0 = tumu; sabitlenmisler haric. */
    @Query("SELECT t FROM ForumTopic t WHERE t.pinnedAt IS NULL AND (:cat = 0L OR t.categoryId = :cat) "
            + "AND t.id < :before AND " + VISIBLE + " ORDER BY t.id DESC")
    List<ForumTopic> newest(@Param("cat") long categoryId, @Param("before") long before,
                            @Param("viewer") Long viewer, @Param("hidden") Collection<Long> hidden, Pageable page);

    /** MOST_COMMENTED: (yorum sayisi, id) azalan anahtar kume; sabitlenmisler dahil (yalniz NEWEST/FOR_YOU onde gosterir). */
    @Query("SELECT t FROM ForumTopic t WHERE (:cat = 0L OR t.categoryId = :cat) "
            + "AND (t.commentCount < :cc OR (t.commentCount = :cc AND t.id < :before)) AND " + VISIBLE
            + " ORDER BY t.commentCount DESC, t.id DESC")
    List<ForumTopic> mostCommented(@Param("cat") long categoryId, @Param("cc") int commentCount,
                                   @Param("before") long before, @Param("viewer") Long viewer,
                                   @Param("hidden") Collection<Long> hidden, Pageable page);

    /**
     * POPULAR: puan = begeni + 2 * yorum, son {@code since} ici olusturulanlar; (puan, id) azalan. Puan ifadesi
     * tam sayidir: imlec karsilastirmasi kayan nokta yuvarlamasina bagli degildir.
     */
    @Query("SELECT t FROM ForumTopic t WHERE (:cat = 0L OR t.categoryId = :cat) AND t.createdAt >= :since "
            + "AND ((t.likeCount + 2 * t.commentCount) < :score OR ((t.likeCount + 2 * t.commentCount) = :score "
            + "AND t.id < :before)) AND " + VISIBLE + " ORDER BY (t.likeCount + 2 * t.commentCount) DESC, t.id DESC")
    List<ForumTopic> popular(@Param("cat") long categoryId, @Param("since") Instant since,
                             @Param("score") int score, @Param("before") long before, @Param("viewer") Long viewer,
                             @Param("hidden") Collection<Long> hidden, Pageable page);

    /** FOR_YOU aday penceresi: son etkinligi {@code since} sonrasi olan, sabitlenmemis konular (puani Java hesaplar). */
    @Query("SELECT t FROM ForumTopic t WHERE t.pinnedAt IS NULL AND (:cat = 0L OR t.categoryId = :cat) "
            + "AND t.lastActivityAt >= :since AND " + VISIBLE + " ORDER BY t.lastActivityAt DESC, t.id DESC")
    List<ForumTopic> candidates(@Param("cat") long categoryId, @Param("since") Instant since,
                                @Param("viewer") Long viewer, @Param("hidden") Collection<Long> hidden, Pageable page);

    /**
     * FOLLOWING: takip ettigim konular (follow=true) + takip ettigim kullanicilarin ANONIM OLMAYAN konulari
     *; id azalan, sabitlenmisler dahil.
     */
    @Query("SELECT t FROM ForumTopic t WHERE (:cat = 0L OR t.categoryId = :cat) AND t.id < :before AND "
            + "(t.id IN (SELECT f.id.topicId FROM ForumTopicFollow f WHERE f.id.userId = :viewer AND f.follow = TRUE) "
            + "OR (t.anonymous = FALSE AND t.userId IN (SELECT uf.id.b FROM edu.bingol.backend.post.follow.UserFollow uf WHERE uf.id.a = :viewer))) AND " + VISIBLE + " ORDER BY t.id DESC")
    List<ForumTopic> following(@Param("cat") long categoryId, @Param("before") long before,
                               @Param("viewer") Long viewer, @Param("hidden") Collection<Long> hidden, Pageable page);

    /** Sabitlenmis konular (en yeni sabitleme basta). */
    @Query("SELECT t FROM ForumTopic t WHERE t.pinnedAt IS NOT NULL AND (:cat = 0L OR t.categoryId = :cat) AND "
            + VISIBLE + " ORDER BY t.pinnedAt DESC, t.id DESC")
    List<ForumTopic> pinned(@Param("cat") long categoryId, @Param("viewer") Long viewer,
                            @Param("hidden") Collection<Long> hidden, Pageable page);

    // ------------------------------------------------------------------ FOR_YOU yakinlik girdileri

    /** Benim son 90 gunde actigim/begendigim/takip ettigim konularin kategorileri (kategori bonusu). */
    @Query("SELECT DISTINCT t.categoryId FROM ForumTopic t WHERE t.deletedAt IS NULL AND ("
            + "(t.userId = :viewer AND t.createdAt >= :since) OR t.id IN (SELECT l.id.topicId FROM ForumTopicLike l "
            + "WHERE l.id.userId = :viewer AND l.createdAt >= :since) OR t.id IN (SELECT f.id.topicId FROM "
            + "ForumTopicFollow f WHERE f.id.userId = :viewer AND f.follow = TRUE AND f.createdAt >= :since))")
    List<Long> affinityCategories(@Param("viewer") Long viewer, @Param("since") Instant since);

    // ------------------------------------------------------------------ yazma (atomik)

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE ForumTopic t SET t.likeCount = t.likeCount + :d WHERE t.id = :id AND (t.likeCount + :d) >= 0")
    int addLikes(@Param("id") Long id, @Param("d") int delta);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE ForumTopic t SET t.bookmarkCount = t.bookmarkCount + :d WHERE t.id = :id AND (t.bookmarkCount + :d) >= 0")
    int addBookmarks(@Param("id") Long id, @Param("d") int delta);

    @Query("SELECT t.likeCount FROM ForumTopic t WHERE t.id = :id")
    Optional<Integer> likeCountOf(@Param("id") Long id);

    @Query("SELECT t.userId FROM ForumTopic t WHERE t.id = :id")
    Optional<Long> authorOf(@Param("id") Long id);

    long countByCategoryIdAndDeletedAtIsNullAndStatus(Long categoryId, String status);

    @Query("SELECT t.categoryId, COUNT(t) FROM ForumTopic t WHERE t.deletedAt IS NULL AND t.status = 'ACTIVE' "
            + "GROUP BY t.categoryId")
    List<Object[]> countsByCategory();

    /** KVKK: kullanicinin gorunur konulari (sayfa sayfa yumusak silinir). */
    @Query("SELECT t FROM ForumTopic t WHERE t.userId = :uid AND t.deletedAt IS NULL ORDER BY t.id")
    List<ForumTopic> ownedBy(@Param("uid") Long userId, Pageable page);
}
