package edu.bingol.backend.post.follow;

import edu.bingol.backend.post.social.PairId;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserFollowRepository extends JpaRepository<UserFollow, PairId> {

    String FOLLOWERS_OF = "SELECT f FROM UserFollow f WHERE f.id.b = :target AND "
            + "EXISTS (SELECT 1 FROM User u WHERE u.id = f.id.a AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE) AND "
            + "NOT EXISTS (SELECT 1 FROM UserBlock b WHERE (b.blockerId = :viewer AND b.blockedId = f.id.a) "
            + "OR (b.blockerId = f.id.a AND b.blockedId = :viewer)) ";
    String FOLLOWING_OF = "SELECT f FROM UserFollow f WHERE f.id.a = :target AND "
            + "EXISTS (SELECT 1 FROM User u WHERE u.id = f.id.b AND u.status = edu.bingol.backend.user.UserStatus.ACTIVE) AND "
            + "NOT EXISTS (SELECT 1 FROM UserBlock b WHERE (b.blockerId = :viewer AND b.blockedId = f.id.b) "
            + "OR (b.blockerId = f.id.b AND b.blockedId = :viewer)) ";
    @Query(FOLLOWERS_OF + "ORDER BY f.createdAt DESC, f.id.a DESC")
    List<UserFollow> followersFirst(@Param("target") Long target, @Param("viewer") Long viewer, Pageable page);

    @Query(FOLLOWERS_OF + "AND (f.createdAt < :at OR (f.createdAt = :at AND f.id.a < :cid)) "
            + "ORDER BY f.createdAt DESC, f.id.a DESC")
    List<UserFollow> followersAfter(@Param("target") Long target, @Param("viewer") Long viewer,
                                    @Param("at") Instant at, @Param("cid") Long cid, Pageable page);

    @Query(FOLLOWING_OF + "ORDER BY f.createdAt DESC, f.id.b DESC")
    List<UserFollow> followingFirst(@Param("target") Long target, @Param("viewer") Long viewer, Pageable page);

    @Query(FOLLOWING_OF + "AND (f.createdAt < :at OR (f.createdAt = :at AND f.id.b < :cid)) "
            + "ORDER BY f.createdAt DESC, f.id.b DESC")
    List<UserFollow> followingAfter(@Param("target") Long target, @Param("viewer") Long viewer,
                                    @Param("at") Instant at, @Param("cid") Long cid, Pageable page);

    /** Bakanin takip ettikleri (verilen kimlikler icinden). */
    @Query("SELECT f.id.b FROM UserFollow f WHERE f.id.a = :viewer AND f.id.b IN :ids")
    List<Long> followedAmong(@Param("viewer") Long viewer, @Param("ids") Collection<Long> ids);

    @Query("SELECT f FROM UserFollow f WHERE f.id.a = :uid OR f.id.b = :uid")
    List<UserFollow> involving(@Param("uid") Long uid);
}
