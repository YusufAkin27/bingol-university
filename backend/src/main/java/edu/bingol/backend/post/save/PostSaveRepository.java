package edu.bingol.backend.post.save;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostSaveRepository extends JpaRepository<PostSave, PostSaveId> {

    @Modifying
    @Query("DELETE FROM PostSave s WHERE s.id.userId = :uid AND s.id.postId = :pid")
    int deleteSave(@Param("uid") Long userId, @Param("pid") Long postId);

    @Query("SELECT s.id.postId FROM PostSave s WHERE s.id.userId = :uid AND s.id.postId IN :ids")
    List<Long> savedAmong(@Param("uid") Long userId, @Param("ids") Collection<Long> postIds);

    @Query("SELECT COUNT(s) FROM PostSave s WHERE s.id.postId = :pid")
    long countByPost(@Param("pid") Long postId);

    /** Kaydedilenler: yalniz bakana hala GORUNUR gonderiler (silinmis/gizli/engelli/gizli hesap sessizce elenir), yeni kaydedilen once. */
    String SAVED = "SELECT p FROM Post p, PostSave s WHERE s.id.postId = p.id AND s.id.userId = :viewer AND "
            + PostRepository.VISIBLE;

    @Query(SAVED + "ORDER BY s.createdAt DESC, p.id DESC")
    List<Post> savedFirst(@Param("viewer") Long viewer, Pageable page);

    @Query(SAVED + "AND (s.createdAt < :at OR (s.createdAt = :at AND p.id < :cid)) ORDER BY s.createdAt DESC, p.id DESC")
    List<Post> savedAfter(@Param("viewer") Long viewer, @Param("at") Instant at, @Param("cid") Long cid, Pageable page);

    @Query("SELECT s.createdAt FROM PostSave s WHERE s.id.userId = :uid AND s.id.postId = :pid")
    List<Instant> savedAt(@Param("uid") Long userId, @Param("pid") Long postId);
}
