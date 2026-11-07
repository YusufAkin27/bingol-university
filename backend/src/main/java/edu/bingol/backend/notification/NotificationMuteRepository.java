package edu.bingol.backend.notification;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationMuteRepository extends JpaRepository<NotificationMute, NotificationMute.Key> {

    boolean existsByUserIdAndTargetTypeAndTargetId(Long userId, String targetType, Long targetId);

    long countByUserId(Long userId);

    List<NotificationMute> findTop500ByUserIdOrderByCreatedAtDesc(Long userId);

    @Modifying
    @Query("DELETE FROM NotificationMute m WHERE m.userId = :uid AND m.targetType = :t AND m.targetId = :id")
    int remove(@Param("uid") Long uid, @Param("t") String type, @Param("id") Long id);

    /** Verilen alicilar arasinda bu kaynagi sessize alanlar (tek sorgu). */
    @Query("SELECT m.userId FROM NotificationMute m WHERE m.targetType = :t AND m.targetId = :id AND m.userId IN :ids")
    List<Long> mutedAmong(@Param("t") String type, @Param("id") Long id, @Param("ids") Collection<Long> ids);
}
