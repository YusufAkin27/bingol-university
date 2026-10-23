package edu.bingol.backend.notification;

import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @Query("SELECT n FROM Notification n WHERE n.userId = :uid AND (:cursor IS NULL OR n.id < :cursor) ORDER BY n.id DESC")
    List<Notification> page(@Param("uid") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    long countByUserIdAndReadAtIsNull(Long userId);

    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = CURRENT_TIMESTAMP WHERE n.userId = :uid AND n.readAt IS NULL AND n.id IN :ids")
    int markRead(@Param("uid") Long userId, @Param("ids") Collection<Long> ids);

    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = CURRENT_TIMESTAMP WHERE n.userId = :uid AND n.readAt IS NULL")
    int markAllRead(@Param("uid") Long userId);

    /** Aktif ve turu kapatmamis tum kullanicilara uygulama ici bildirim satiri ekler. */
    @Transactional
    @Modifying
    @Query(value = """
            INSERT INTO notification (user_id, type, title, body, data, created_at)
            SELECT u.id, :type, :title, :body, :data, now() FROM app_user u
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE u.status = 'ACTIVE' AND u.email_verified = TRUE
              AND COALESCE(CASE :col WHEN 'news' THEN p.news WHEN 'announcements' THEN p.announcements
                                     WHEN 'events' THEN p.events WHEN 'messages' THEN p.messages
                                     WHEN 'communities' THEN p.communities ELSE TRUE END, TRUE)
            """, nativeQuery = true)
    int insertForAll(@Param("type") String type, @Param("title") String title, @Param("body") String body,
                     @Param("data") String data, @Param("col") String prefColumn);
}
