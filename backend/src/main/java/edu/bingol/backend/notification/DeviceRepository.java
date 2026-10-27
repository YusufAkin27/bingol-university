package edu.bingol.backend.notification;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface DeviceRepository extends JpaRepository<Device, Long> {

    Optional<Device> findByFcmToken(String fcmToken);

    List<Device> findByUserId(Long userId);

    List<Device> findByUserIdOrderByUpdatedAtDesc(Long userId);

    @Transactional
    @Modifying
    void deleteByFcmTokenAndUserId(String fcmToken, Long userId);

    @Transactional
    @Modifying
    @Query("DELETE FROM Device d WHERE d.lastSeenAt < :cutoff")
    int deleteStale(@Param("cutoff") java.time.Instant cutoff);

    /** Tek cihaz kurali: yeni mobil giriste kullanicinin onceki cihaz kayitlari silinir. */
    @Transactional
    @Modifying
    @Query("DELETE FROM Device d WHERE d.userId = :userId")
    int deleteAllByUser(@Param("userId") Long userId);

    @Transactional
    @Modifying
    void deleteByFcmTokenIn(Collection<String> tokens);

    /**
     * Verilen turu kapatmamis, aktif ve sessiz saatte olmayan kullanicilarin cihaz token'lari (toplu bildirim icin).
     * Sessiz saatteki kullanicilarin uygulama ici kaydi dusulur, yalnizca push atlanir (SYSTEM haric).
     */
    @Query(value = """
            SELECT d.fcm_token FROM device d
            JOIN app_user u ON u.id = d.user_id AND u.status = 'ACTIVE'
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE COALESCE(CASE :col WHEN 'news' THEN p.news WHEN 'announcements' THEN p.announcements
                                     WHEN 'events' THEN p.events WHEN 'messages' THEN p.messages
                                     WHEN 'communities' THEN p.communities ELSE TRUE END, TRUE)
              AND """ + QuietSql.NOT_QUIET, nativeQuery = true)
    List<String> tokensForBroadcast(@Param("col") String prefColumn);

    /** Belirli dildeki kullanicilarin token'lari (dilde yerellestirilmis toplu bildirim). */
    @Query(value = """
            SELECT d.fcm_token FROM device d
            JOIN app_user u ON u.id = d.user_id AND u.status = 'ACTIVE' AND u.language = :lang
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE COALESCE(CASE :col WHEN 'news' THEN p.news WHEN 'announcements' THEN p.announcements
                                     WHEN 'events' THEN p.events WHEN 'messages' THEN p.messages
                                     WHEN 'communities' THEN p.communities ELSE TRUE END, TRUE)
              AND """ + QuietSql.NOT_QUIET, nativeQuery = true)
    List<String> tokensForBroadcastLang(@Param("col") String prefColumn, @Param("lang") String lang);

    /** Kullanici listesi icin token'lar; sessiz saatteki kullanicilar (SYSTEM haric) atlanir. */
    @Query(value = """
            SELECT d.fcm_token FROM device d
            LEFT JOIN notification_pref p ON p.user_id = d.user_id
            WHERE d.user_id IN (:ids) AND """ + QuietSql.NOT_QUIET, nativeQuery = true)
    List<String> tokensForUsers(@Param("ids") Collection<Long> userIds, @Param("col") String prefColumn);
}
