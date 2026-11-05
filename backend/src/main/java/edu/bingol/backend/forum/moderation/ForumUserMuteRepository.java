package edu.bingol.backend.forum.moderation;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ForumUserMuteRepository extends JpaRepository<ForumUserMute, ForumUserMute.Key> {

    boolean existsByUserIdAndMutedUserId(Long userId, Long mutedUserId);

    long countByUserId(Long userId);

    @Query("SELECT m.mutedUserId FROM ForumUserMute m WHERE m.userId = :uid")
    List<Long> mutedIds(@Param("uid") Long userId);

    @Query("SELECT m FROM ForumUserMute m WHERE m.userId = :uid ORDER BY m.createdAt DESC, m.mutedUserId DESC")
    List<ForumUserMute> page(@Param("uid") Long userId, Pageable pageable);

    @Modifying
    @Query("DELETE FROM ForumUserMute m WHERE m.userId = :uid AND m.mutedUserId = :muted")
    int remove(@Param("uid") Long userId, @Param("muted") Long mutedUserId);
}
