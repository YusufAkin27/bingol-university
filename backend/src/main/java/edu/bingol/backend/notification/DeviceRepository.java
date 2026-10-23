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

    @Transactional
    @Modifying
    void deleteByFcmTokenAndUserId(String fcmToken, Long userId);

    @Transactional
    @Modifying
    void deleteByFcmTokenIn(Collection<String> tokens);

    /** Verilen turu kapatmamis, aktif kullanicilarin cihaz token'lari (toplu bildirim icin). */
    @Query(value = """
            SELECT d.fcm_token FROM device d
            JOIN app_user u ON u.id = d.user_id AND u.status = 'ACTIVE'
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE COALESCE(CASE :col WHEN 'news' THEN p.news WHEN 'announcements' THEN p.announcements
                                     WHEN 'events' THEN p.events WHEN 'messages' THEN p.messages
                                     WHEN 'communities' THEN p.communities ELSE TRUE END, TRUE)
            """, nativeQuery = true)
    List<String> tokensForBroadcast(@Param("col") String prefColumn);
}
