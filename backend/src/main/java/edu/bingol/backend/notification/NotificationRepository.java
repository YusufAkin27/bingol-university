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

    @Query("SELECT n FROM Notification n WHERE n.userId = :uid AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE "
            + "AND (:cursor IS NULL OR n.id < :cursor) ORDER BY n.id DESC")
    List<Notification> page(@Param("uid") Long userId, @Param("cursor") Long cursor, Pageable pageable);

    /** Tur ve okunmamis filtreli liste; "tum turler" icin types'a tum turler verilir. */
    @Query("""
            SELECT n FROM Notification n WHERE n.userId = :uid AND (:cursor IS NULL OR n.id < :cursor)
              AND n.type IN :types AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE
              AND (:unreadOnly = FALSE OR n.readAt IS NULL) ORDER BY n.id DESC""")
    List<Notification> pageFiltered(@Param("uid") Long userId, @Param("cursor") Long cursor,
                                    @Param("types") Collection<NotificationType> types,
                                    @Param("unreadOnly") boolean unreadOnly, Pageable pageable);

    /** Category is applied before pagination; the unread count remains the global inbox count. */
    @Query("""
            SELECT n FROM Notification n WHERE n.userId = :uid AND (:cursor IS NULL OR n.id < :cursor)
              AND n.type IN :types AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE
              AND (:unreadOnly = FALSE OR n.readAt IS NULL)
              AND (CASE
                WHEN n.subtype = 'POLL' OR n.data LIKE '%"pollId"%' OR (replace(n.data, ' ', '') LIKE '%"target":"POLL%' OR replace(n.data, ' ', '') LIKE '%"targetType":"POLL%') THEN 'POLL'
                WHEN n.subtype IN ('EXAM_REMINDER', 'ACADEMIC_ANNOUNCEMENT')
                  OR n.data LIKE '%"examId"%' OR (replace(n.data, ' ', '') LIKE '%"target":"ACADEMIC%' OR replace(n.data, ' ', '') LIKE '%"targetType":"ACADEMIC%')
                  OR (replace(n.data, ' ', '') LIKE '%"target":"EXAM"%' OR replace(n.data, ' ', '') LIKE '%"targetType":"EXAM"%') OR (replace(n.data, ' ', '') LIKE '%"target":"TIMETABLE"%' OR replace(n.data, ' ', '') LIKE '%"targetType":"TIMETABLE"%')
                  OR (replace(n.data, ' ', '') LIKE '%"target":"ANNOUNCEMENT_DEPT"%' OR replace(n.data, ' ', '') LIKE '%"targetType":"ANNOUNCEMENT_DEPT"%') THEN 'ACADEMIC'
                WHEN n.type = edu.bingol.backend.notification.NotificationType.COMMUNITY AND n.subtype = 'COMMUNITY_JOIN' THEN 'SOCIAL'
                WHEN n.type = edu.bingol.backend.notification.NotificationType.EVENT THEN 'EVENT'
                WHEN n.type IN (edu.bingol.backend.notification.NotificationType.POST_LIKE,
                  edu.bingol.backend.notification.NotificationType.POST_COMMENT,
                  edu.bingol.backend.notification.NotificationType.COMMENT_REPLY,
                  edu.bingol.backend.notification.NotificationType.POST_MENTION,
                  edu.bingol.backend.notification.NotificationType.USER_FOLLOW,
                  edu.bingol.backend.notification.NotificationType.FOLLOW_REQUEST,
                  edu.bingol.backend.notification.NotificationType.FOLLOW_ACCEPTED,
                  edu.bingol.backend.notification.NotificationType.FORUM) THEN 'SOCIAL'
                WHEN n.type = edu.bingol.backend.notification.NotificationType.SYSTEM THEN 'SYSTEM'
                ELSE 'ANNOUNCEMENT' END) IN :categories
              ORDER BY n.id DESC""")
    List<Notification> pageCategory(@Param("uid") Long userId, @Param("cursor") Long cursor,
                                    @Param("types") Collection<NotificationType> types,
                                    @Param("unreadOnly") boolean unreadOnly, @Param("categories") Collection<String> categories,
                                    Pageable pageable);

    /**
     * SOCIAL kapsam kosulu (Hareketler/kalp) TEK yerde: sosyal turler + kulup uyelik basvurusu alt turu. Bunun disindaki
     * (MESSAGE haric) her sey INFORMATION (zil). NotificationPresentation.category ile birebir tutulur (test denetler).
     */
    String SOCIAL_COND = "(n.type IN (edu.bingol.backend.notification.NotificationType.POST_LIKE, "
            + "edu.bingol.backend.notification.NotificationType.POST_COMMENT, "
            + "edu.bingol.backend.notification.NotificationType.COMMENT_REPLY, "
            + "edu.bingol.backend.notification.NotificationType.POST_MENTION, "
            + "edu.bingol.backend.notification.NotificationType.USER_FOLLOW, "
            + "edu.bingol.backend.notification.NotificationType.FOLLOW_REQUEST, "
            + "edu.bingol.backend.notification.NotificationType.FOLLOW_ACCEPTED, "
            + "edu.bingol.backend.notification.NotificationType.FORUM) "
            + "OR (n.type = edu.bingol.backend.notification.NotificationType.COMMUNITY AND n.subtype = 'COMMUNITY_JOIN'))";

    /** Kapsama gore liste: social=true Hareketler (kalp), false Bildirimler (zil: sosyal/sohbet icermez). */
    @Query("SELECT n FROM Notification n WHERE n.userId = :uid AND (:cursor IS NULL OR n.id < :cursor) "
            + "AND n.type IN :types AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE "
            + "AND (:unreadOnly = FALSE OR n.readAt IS NULL) "
            + "AND ((:social = TRUE AND " + SOCIAL_COND + ") OR (:social = FALSE AND NOT " + SOCIAL_COND + ")) "
            + "AND (:kind = 'ALL' OR :kind = CASE "
            + "WHEN n.type = edu.bingol.backend.notification.NotificationType.POST_LIKE "
            + "OR n.subtype IN ('FORUM_TOPIC_LIKE','FORUM_COMMENT_LIKE') THEN 'LIKES' "
            + "WHEN n.type IN (edu.bingol.backend.notification.NotificationType.POST_COMMENT, "
            + "edu.bingol.backend.notification.NotificationType.COMMENT_REPLY) "
            + "OR n.subtype IN ('FORUM_TOPIC_COMMENT','FORUM_COMMENT_REPLY','FORUM_FOLLOWED_TOPIC_COMMENT') THEN 'COMMENTS' "
            + "WHEN n.type IN (edu.bingol.backend.notification.NotificationType.USER_FOLLOW, "
            + "edu.bingol.backend.notification.NotificationType.FOLLOW_REQUEST, "
            + "edu.bingol.backend.notification.NotificationType.FOLLOW_ACCEPTED) OR n.subtype = 'COMMUNITY_JOIN' THEN 'FOLLOWS' "
            + "ELSE 'OTHER' END) "
            + "ORDER BY n.id DESC")
    List<Notification> pageScope(@Param("uid") Long userId, @Param("cursor") Long cursor,
                                 @Param("types") Collection<NotificationType> types,
                                 @Param("unreadOnly") boolean unreadOnly, @Param("social") boolean social,
                                 @Param("kind") String kind, Pageable pageable);

    @Query("SELECT COUNT(n) FROM Notification n WHERE n.userId = :uid AND n.readAt IS NULL "
            + "AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE "
            + "AND ((:social = TRUE AND " + SOCIAL_COND + ") OR (:social = FALSE AND NOT " + SOCIAL_COND + "))")
    long countUnreadScope(@Param("uid") Long userId, @Param("social") boolean social);

    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL "
            + "AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE "
            + "AND ((:social = TRUE AND " + SOCIAL_COND + ") OR (:social = FALSE AND NOT " + SOCIAL_COND + "))")
    int markAllReadScopeAt(@Param("uid") Long userId, @Param("social") boolean social, @Param("now") Instant now);

    long countByUserIdAndReadAtIsNull(Long userId);

    /**
     * Gelen kutusu okunmamis sayisi: sohbet mesaji (MESSAGE) kutuda gosterilmez/sayilmaz (eski MESSAGE satirlari gece
     * isiyle silinir). Liste, rozet ve unread-count TEK bu tanima bagli.
     */
    @Query("SELECT COUNT(n) FROM Notification n WHERE n.userId = :uid AND n.readAt IS NULL "
            + "AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE")
    long countUnreadInbox(@Param("uid") Long userId);

    Optional<Notification> findByIdAndUserId(Long id, Long userId);

    Optional<Notification> findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(Long userId, String collapseKey);

    /** Okunmus olsa da ayni anahtarli kayit var mi (takip bildirimi tekrarini onlemek icin). */
    boolean existsByUserIdAndCollapseKey(Long userId, String collapseKey);

    List<Notification> findTop500ByUserIdOrderByIdDesc(Long userId);

    // --- Toplu sohbet bildirimi (NotificationService.sendNewMessageBatch): alici basina degil parca basina TEK sorgu ---

    /** Verilen alt turu KAPATMIS kullanicilar (satir yoksa acik sayilir). */
    @Query("SELECT s.userId FROM NotificationSubtypePref s WHERE s.userId IN :ids AND s.subtype = :subtype "
            + "AND s.enabled = false")
    List<Long> subtypeDisabledAmong(@Param("ids") Collection<Long> userIds, @Param("subtype") String subtype);

    /** Kullanici -> FCM token cifti (cihaz basina bir satir). */
    @Query("SELECT d.userId, d.fcmToken FROM Device d WHERE d.userId IN :ids")
    List<Object[]> deviceTokensOf(@Param("ids") Collection<Long> userIds);

    /** Kullanici basina okunmamis bildirim sayisi (rozet): [userId, adet]; sifir olanlar donmez. */
    @Query("SELECT n.userId, COUNT(n) FROM Notification n WHERE n.userId IN :ids AND n.readAt IS NULL "
            + "AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE GROUP BY n.userId")
    List<Object[]> unreadCountsOf(@Param("ids") Collection<Long> userIds);

    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL AND n.id IN :ids")
    int markReadAt(@Param("uid") Long userId, @Param("ids") Collection<Long> ids, @Param("now") Instant now);

    default int markRead(Long userId, Collection<Long> ids) {
        return markReadAt(userId, ids, Instant.now());
    }

    /** Belirli birlesme anahtarli (ornek `conv:5`) okunmamis satirlari okundu yapar (sohbet okununca). */
    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL AND n.collapseKey = :key")
    int markReadByCollapseKey(@Param("uid") Long userId, @Param("key") String collapseKey, @Param("now") Instant now);

    /** Tur + birlesme anahtari ile eslesen okunmamis satirlari okundu yapar (takip istegi artik gecersiz). */
    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL "
            + "AND n.type = :type AND n.collapseKey = :key")
    int markReadByTypeAndCollapseKey(@Param("uid") Long userId, @Param("type") NotificationType type,
                                     @Param("key") String collapseKey, @Param("now") Instant now);

    /** Tur + birlesme anahtari ile eslesen TUM satirlari (okunmus/okunmamis) siler: geri cekilen takip istegi. */
    @Transactional
    @Modifying
    @Query("DELETE FROM Notification n WHERE n.userId = :uid AND n.type = :type AND n.collapseKey = :key")
    int deleteByTypeAndCollapseKey(@Param("uid") Long userId, @Param("type") NotificationType type,
                                   @Param("key") String collapseKey);

    /**
     * Tur + anahtar oneki (LIKE; {@code pattern} onceden kacirilmis, kacis karakteri {@code \}) ile eslesen okunmamis
     * satirlari okundu yapar. Gizli->acik toplu otomatik kabulde TEK sorgu.
     */
    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL "
            + "AND n.type = :type AND n.collapseKey LIKE :pattern ESCAPE '\\'")
    int markReadByTypeAndCollapseKeyLike(@Param("uid") Long userId, @Param("type") NotificationType type,
                                         @Param("pattern") String pattern, @Param("now") Instant now);

    @Transactional
    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.userId = :uid AND n.readAt IS NULL "
            + "AND n.type <> edu.bingol.backend.notification.NotificationType.MESSAGE")
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
                                     WHEN 'communities' THEN p.communities
                                     WHEN 'polls' THEN (p.polls AND p.announcements)
                                     WHEN 'academic_announcements' THEN (p.academic_announcements AND p.announcements) ELSE TRUE END, TRUE)
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
                                     WHEN 'communities' THEN p.communities
                                     WHEN 'polls' THEN (p.polls AND p.announcements)
                                     WHEN 'academic_announcements' THEN (p.academic_announcements AND p.announcements) ELSE TRUE END, TRUE)
            """, nativeQuery = true)
    int insertForLang(@Param("type") String type, @Param("title") String title, @Param("body") String body,
                      @Param("data") String data, @Param("col") String prefColumn, @Param("lang") String lang);
}
