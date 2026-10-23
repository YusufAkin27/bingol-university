package edu.bingol.backend.notification;

import java.time.Instant;
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
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL AND n.id IN :ids")
    int markReadAt(@Param("uid") Long userId, @Param("ids") Collection<Long> ids, @Param("now") Instant now);

    default int markRead(Long userId, Collection<Long> ids) {
        return markReadAt(userId, ids, Instant.now());
    }

    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL")
    int markAllReadAt(@Param("uid") Long userId, @Param("now") Instant now);

    default int markAllRead(Long userId) {
        return markAllReadAt(userId, Instant.now());
    }

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

    /** insertForAll ile ayni, yalnizca belirli dildeki kullanicilar icin. */
    @Transactional
    @Modifying
    @Query(value = """
            INSERT INTO notification (user_id, type, title, body, data, created_at)
            SELECT u.id, :type, :title, :body, :data, now() FROM app_user u
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE u.status = 'ACTIVE' AND u.email_verified = TRUE AND u.language = :lang
              AND COALESCE(CASE :col WHEN 'news' THEN p.news WHEN 'announcements' THEN p.announcements
                                     WHEN 'events' THEN p.events WHEN 'messages' THEN p.messages
                                     WHEN 'communities' THEN p.communities ELSE TRUE END, TRUE)
            """, nativeQuery = true)
    int insertForLang(@Param("type") String type, @Param("title") String title, @Param("body") String body,
                      @Param("data") String data, @Param("col") String prefColumn, @Param("lang") String lang);
}
