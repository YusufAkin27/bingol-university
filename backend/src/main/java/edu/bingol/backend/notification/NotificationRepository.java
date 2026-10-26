package edu.bingol.backend.notification;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @Query("SELECT n FROM Notification n WHERE n.userId = :uid AND (:cursor IS NULL OR n.id < :cursor) ORDER BY n.id DESC")
    List<Notification> page(@Param("uid") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    /** Tur ve okunmamis filtreli liste; "tum turler" icin types'a tum turler verilir. */
    @Query("""
            SELECT n FROM Notification n WHERE n.userId = :uid AND (:cursor IS NULL OR n.id < :cursor)
              AND n.type IN :types AND (:unreadOnly = FALSE OR n.readAt IS NULL) ORDER BY n.id DESC""")
    List<Notification> pageFiltered(@Param("uid") Long userId, @Param("cursor") Long cursor,
                                    @Param("types") Collection<NotificationType> types,
                                    @Param("unreadOnly") boolean unreadOnly, Pageable pageable);

    long countByUserIdAndReadAtIsNull(Long userId);

    Optional<Notification> findByIdAndUserId(Long id, Long userId);

    Optional<Notification> findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(Long userId, String collapseKey);

    List<Notification> findTop500ByUserIdOrderByIdDesc(Long userId);

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

    @Transactional
    @Modifying
    @Query("DELETE FROM Notification n WHERE n.userId = :uid AND n.id = :id")
    int deleteOne(@Param("uid") Long userId, @Param("id") Long id);

    /** Kullanicinin bildirimlerini siler; types ile daraltilir, readOnly=true ise yalnizca okunmuslar. */
    @Transactional
    @Modifying
    @Query("""
            DELETE FROM Notification n WHERE n.userId = :uid AND n.type IN :types
              AND (:readOnly = FALSE OR n.readAt IS NOT NULL)""")
    int deleteForUser(@Param("uid") Long userId, @Param("types") Collection<NotificationType> types,
                      @Param("readOnly") boolean readOnly);

    /** Saklama suresi: okunmus bildirimleri okunma zamanina gore siler. */
    @Transactional
    @Modifying
    @Query("DELETE FROM Notification n WHERE n.readAt IS NOT NULL AND n.readAt < :cutoff")
    int deleteReadBefore(@Param("cutoff") Instant cutoff);

    /** Hic okunmamis eski bildirimler icin ust sinir. */
    @Transactional
    @Modifying
    @Query("DELETE FROM Notification n WHERE n.readAt IS NULL AND n.createdAt < :cutoff")
    int deleteUnreadBefore(@Param("cutoff") Instant cutoff);

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
