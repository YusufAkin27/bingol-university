package edu.bingol.backend.post.media;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostMediaRepository extends JpaRepository<PostMedia, Long> {

    /** Erisim karari icin gonderinin durumu (gonderi satirina baska modulun deposu olmadan bakilir). */
    interface PostState {
        Long getAuthorId();

        Instant getDeletedAt();

        Instant getHiddenAt();

        /** Yazarin hesap durumu (ACTIVE degilse gonderi akistan dusmustur; medyasi da kapali olmali). */
        edu.bingol.backend.user.UserStatus getAuthorStatus();
    }

    @Query("SELECT p.authorId AS authorId, p.deletedAt AS deletedAt, p.hiddenAt AS hiddenAt, u.status AS authorStatus "
            + "FROM Post p LEFT JOIN User u ON u.id = p.authorId WHERE p.id = :id")
    Optional<PostState> postState(@Param("id") Long postId);

    /**
     * Supurucu icin saklama anahtarlari: kimlik imleciyle sayfali [id, storageKey]. Dosya basina sorgu yerine kume
     * bir kez bellege alinir (post_media'da storage_key indeksi ayrica V1120 ile vardir).
     */
    @Query("SELECT m.id, m.storageKey FROM PostMedia m WHERE m.id > :after ORDER BY m.id")
    List<Object[]> keysAfter(@Param("after") long after, Pageable page);

    List<PostMedia> findByPostIdIn(Collection<Long> postIds);

    List<PostMedia> findByPostIdOrderByPositionAscIdAsc(Long postId);

    List<PostMedia> findByOwnerId(Long ownerId);

    long countByOwnerIdAndPostIdIsNull(Long ownerId);


    boolean existsByStorageKey(String storageKey);

    /** Atomik baglama: yalniz sahibinin, baglanmamis, gizli olmayan medya. Donen 1 degilse gecersiz/yarisilmis. */
    // clearAutomatically: ayni islemde onceden yuklenen (postId=null) nesne bayat kalmasin; yoksa gorunum siralamasi NPE verir
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE PostMedia m SET m.postId = :post, m.position = :pos WHERE m.id = :id AND m.ownerId = :owner "
            + "AND m.postId IS NULL AND m.hiddenAt IS NULL")
    int bind(@Param("id") Long id, @Param("owner") Long ownerId, @Param("post") Long postId,
             @Param("pos") short position);

    @Modifying(flushAutomatically = true)
    @Query("UPDATE PostMedia m SET m.hiddenAt = :now WHERE m.postId = :post AND m.hiddenAt IS NULL")
    int hideByPost(@Param("post") Long postId, @Param("now") Instant now);

    @Modifying(flushAutomatically = true)
    @Query("UPDATE PostMedia m SET m.hiddenAt = NULL WHERE m.postId = :post AND m.hiddenAt IS NOT NULL")
    int unhideByPost(@Param("post") Long postId);

    /** Baglanmamis ve `before`dan eski yuklemeler (supurucu). */
    @Query("SELECT m FROM PostMedia m WHERE m.postId IS NULL AND m.createdAt < :before ORDER BY m.id")
    List<PostMedia> stale(@Param("before") Instant before, Pageable page);

    /** Silinmesinden (`before`) bu yana saklama suresi dolan gonderilerin medyasi. */
    @Query("SELECT m FROM PostMedia m WHERE m.postId IN (SELECT p.id FROM Post p WHERE p.deletedAt IS NOT NULL "
            + "AND p.deletedAt < :before) ORDER BY m.id")
    List<PostMedia> ofPostsDeletedBefore(@Param("before") Instant before, Pageable page);

    /** Yalniz hala baglanmamissa siler (supurucu ile baglama yarisi). */
    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM PostMedia m WHERE m.id = :id AND m.postId IS NULL")
    int deleteIfUnattached(@Param("id") Long id);
}
