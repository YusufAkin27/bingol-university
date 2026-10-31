package edu.bingol.backend.post.social;

import static edu.bingol.backend.post.PostRepository.LATEST_AFTER;
import static edu.bingol.backend.post.PostRepository.LATEST_ORDER;
import static edu.bingol.backend.post.PostRepository.FEED_VISIBLE;

import edu.bingol.backend.post.Post;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;

/** Akis kapsamlari (takip, bolum): "yeni -> eski" imleci (createdAt, id) ve PostRepository.VISIBLE kurali. */
public interface SocialFeedRepository extends Repository<Post, Long> {

    /**
     * Takip akisinda taranan en cok yazar sayisi (kendisi + en yeni takip edilenler). Cok fazla kisiyi takip edenlerde
     * IN listesi (ve plani) sinirli kalir; gercekci takip sayilari bunun cok altindadir.
     */
    int MAX_FOLLOWED_AUTHORS = 2000;

    /**
     * Takip akisi yazar listesiyle yapilir (T-070): onceki {@code authorId = :viewer OR EXISTS(user_follow ...)} OR kosulu
     * yazar indeksinin (post310_author_idx) kullanilmasini engelliyor, plan zaman tersine TUM gonderileri gezip suzuyordu
     * (21 satir icin 28 bin satir, 26 bin tampon). Acik yazar listesi ile planlayici yazar indeksine gider; maliyet
     * toplam gonderi sayisina degil, takip edilenlerin gonderi sayisina baglidir.
     */
    String FOLLOWING = "p.authorId IN :authors AND ";
    /**
     * T-053: yazarin bolum bilgisi bakana kapaliysa (ONLY_ME / SHARED_CONTEXT) o yazar bolum akisinda yer almaz;
     * aksi halde akis, bolum gizliligini yan kanaldan sizdirirdi. Kendi gonderilerim her zaman gorunur.
     */
    String DEPARTMENT = "p.authorId IN (SELECT u.id FROM User u WHERE u.department = :dept AND (u.id = :viewer "
            + "OR NOT EXISTS (SELECT 1 FROM ProfilePrivacy pp WHERE pp.userId = u.id "
            + "AND pp.departmentAudience <> edu.bingol.backend.profile.privacy.Audience.EVERYONE))) AND ";

    /** Bakanin takip ettikleri, en yeni takip once (siniri Pageable belirler; bkz. {@link #MAX_FOLLOWED_AUTHORS}). */
    @Query("SELECT f.id.b FROM UserFollow f WHERE f.id.a = :viewer ORDER BY f.createdAt DESC, f.id.b DESC")
    List<Long> followeeIds(@Param("viewer") Long viewer, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + FOLLOWING + FEED_VISIBLE + LATEST_ORDER)
    List<Post> followingFirst(@Param("viewer") Long viewer, @Param("authors") Collection<Long> authors, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + FOLLOWING + FEED_VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> followingAfter(@Param("viewer") Long viewer, @Param("authors") Collection<Long> authors,
                              @Param("at") Instant at, @Param("cid") Long cid, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + DEPARTMENT + FEED_VISIBLE + LATEST_ORDER)
    List<Post> departmentFirst(@Param("viewer") Long viewer, @Param("dept") String dept, Pageable page);

    @Query("SELECT p FROM Post p WHERE " + DEPARTMENT + FEED_VISIBLE + LATEST_AFTER + LATEST_ORDER)
    List<Post> departmentAfter(@Param("viewer") Long viewer, @Param("dept") String dept, @Param("at") Instant at,
                               @Param("cid") Long cid, Pageable page);
}
