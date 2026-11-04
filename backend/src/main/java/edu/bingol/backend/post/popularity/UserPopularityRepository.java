package edu.bingol.backend.post.popularity;

import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Popülerlik puanı depo + toplu hesap sorguları (üst düzey arayüz; bean: userPopularityRepository). */
public interface UserPopularityRepository extends JpaRepository<UserPopularity, Long> {

    /** Yazar başına görünür gönderi sayısı ve aldığı toplam beğeni: [authorId, postCount, likes]. */
    @Query("SELECT p.authorId, COUNT(p), COALESCE(SUM(p.likeCount), 0) FROM Post p WHERE p.authorId IN :ids "
            + "AND p.deletedAt IS NULL AND p.hiddenAt IS NULL GROUP BY p.authorId")
    List<Object[]> postAggregates(@Param("ids") Collection<Long> ids);

    /** Takipçi sayıları: [userId, followerCount]. */
    @Query("SELECT f.userId, f.followerCount FROM FollowStats f WHERE f.userId IN :ids")
    List<Object[]> followers(@Param("ids") Collection<Long> ids);

    /** Aktif kullanıcı kimlikleri (kimliğe göre imleçli parça). */
    @Query("SELECT u.id FROM User u WHERE u.status = edu.bingol.backend.user.UserStatus.ACTIVE AND u.id > :after "
            + "ORDER BY u.id")
    List<Long> activeIdsAfter(@Param("after") Long after, Pageable page);

    @Modifying
    @Query("DELETE FROM UserPopularity u WHERE u.userId = :id")
    int deleteByUser(@Param("id") Long userId);
}
