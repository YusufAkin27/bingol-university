package edu.bingol.backend.moderation;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserBlockRepository extends JpaRepository<UserBlock, UserBlock.Key> {

    List<UserBlock> findByBlockerIdOrderByCreatedAtDesc(Long blockerId);

    Slice<UserBlock> findByBlockerIdOrderByCreatedAtDescBlockedIdDesc(Long blockerId, Pageable pageable);

    boolean existsByBlockerIdAndBlockedId(Long blockerId, Long blockedId);

    long countByBlockerId(Long blockerId);

    /** a ile b arasinda herhangi bir yonde engel var mi. */
    @Query("SELECT COUNT(b) > 0 FROM UserBlock b WHERE (b.blockerId = :a AND b.blockedId = :b) OR (b.blockerId = :b AND b.blockedId = :a)")
    boolean existsBetween(@Param("a") Long a, @Param("b") Long b);

    /** Kullanicinin engelledigi veya kendisini engelleyenlerin id'leri. */
    @Query(value = "SELECT blocked_id FROM user_block WHERE blocker_id = :u UNION SELECT blocker_id FROM user_block WHERE blocked_id = :u",
            nativeQuery = true)
    List<Long> relatedIds(@Param("u") Long userId);
}
