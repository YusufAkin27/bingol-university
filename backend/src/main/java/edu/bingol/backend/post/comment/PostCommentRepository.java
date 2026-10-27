package edu.bingol.backend.post.comment;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostCommentRepository extends JpaRepository<PostComment, Long> {

    String LISTED = " c.hiddenAt IS NULL AND (c.deletedAt IS NULL OR c.replyCount > 0) AND c.authorId NOT IN :hidden ";

    // ---- kok yorumlar: yeni ----
    @Query("SELECT c FROM PostComment c WHERE c.postId = :pid AND c.parentId IS NULL AND" + LISTED
            + "ORDER BY c.createdAt DESC, c.id DESC")
    List<PostComment> rootsNew(@Param("pid") Long pid, @Param("hidden") Collection<Long> hidden, Pageable p);

    @Query("SELECT c FROM PostComment c WHERE c.postId = :pid AND c.parentId IS NULL AND" + LISTED
            + "AND (c.createdAt < :at OR (c.createdAt = :at AND c.id < :id)) ORDER BY c.createdAt DESC, c.id DESC")
    List<PostComment> rootsNewAfter(@Param("pid") Long pid, @Param("hidden") Collection<Long> hidden,
            @Param("at") Instant at, @Param("id") Long id, Pageable p);

    // ---- kok yorumlar: top (yanit sayisi, yenilik) ----
    @Query("SELECT c FROM PostComment c WHERE c.postId = :pid AND c.parentId IS NULL AND" + LISTED
            + "ORDER BY c.replyCount DESC, c.createdAt DESC, c.id DESC")
    List<PostComment> rootsTop(@Param("pid") Long pid, @Param("hidden") Collection<Long> hidden, Pageable p);

    @Query("SELECT c FROM PostComment c WHERE c.postId = :pid AND c.parentId IS NULL AND" + LISTED
            + "AND (c.replyCount < :rc OR (c.replyCount = :rc AND (c.createdAt < :at OR (c.createdAt = :at AND c.id < :id)))) "
            + "ORDER BY c.replyCount DESC, c.createdAt DESC, c.id DESC")
    List<PostComment> rootsTopAfter(@Param("pid") Long pid, @Param("hidden") Collection<Long> hidden,
            @Param("rc") int rc, @Param("at") Instant at, @Param("id") Long id, Pageable p);

    // ---- yanitlar: eskiden yeniye ----
    @Query("SELECT c FROM PostComment c WHERE c.parentId = :cid AND" + LISTED + "ORDER BY c.createdAt ASC, c.id ASC")
    List<PostComment> replies(@Param("cid") Long cid, @Param("hidden") Collection<Long> hidden, Pageable p);

    @Query("SELECT c FROM PostComment c WHERE c.parentId = :cid AND" + LISTED
            + "AND (c.createdAt > :at OR (c.createdAt = :at AND c.id > :id)) ORDER BY c.createdAt ASC, c.id ASC")
    List<PostComment> repliesAfter(@Param("cid") Long cid, @Param("hidden") Collection<Long> hidden,
            @Param("at") Instant at, @Param("id") Long id, Pageable p);

    /** Her kok icin en eski {@code n} dogrudan yanit id'leri (tek sorgu, N+1 yok). */
    @Query(value = "SELECT id FROM (SELECT c.id AS id, c.parent_id AS pid, c.created_at AS ca, "
            + "ROW_NUMBER() OVER (PARTITION BY c.parent_id ORDER BY c.created_at ASC, c.id ASC) AS rn "
            + "FROM post_comment c WHERE c.parent_id IN (:roots) AND c.hidden_at IS NULL "
            + "AND (c.deleted_at IS NULL OR c.reply_count > 0) AND c.author_id NOT IN (:hidden)) t "
            + "WHERE rn <= :n ORDER BY pid, ca, id", nativeQuery = true)
    List<Long> previewIds(@Param("roots") Collection<Long> roots, @Param("hidden") Collection<Long> hidden,
            @Param("n") int n);

    @Query("SELECT c FROM PostComment c WHERE c.authorId = :uid AND c.deletedAt IS NULL ORDER BY c.depth DESC, c.id DESC")
    List<PostComment> liveByAuthor(@Param("uid") Long uid);

    @Query("SELECT c FROM PostComment c WHERE c.authorId = :uid ORDER BY c.createdAt DESC, c.id DESC")
    List<PostComment> allByAuthor(@Param("uid") Long uid);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostComment c SET c.replyCount = CASE WHEN c.replyCount + :d < 0 THEN 0 ELSE c.replyCount + :d END WHERE c.id = :id")
    int addReplies(@Param("id") Long id, @Param("d") int d);
}
