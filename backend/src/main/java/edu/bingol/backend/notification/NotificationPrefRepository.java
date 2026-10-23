package edu.bingol.backend.notification;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface NotificationPrefRepository extends JpaRepository<NotificationPref, Long> {

    /** Verilen kullanicilar icinden, bu bildirim turunu kapatmamis olanlar (aktif hesaplar). */
    @Query(value = """
            SELECT u.id FROM app_user u
            LEFT JOIN notification_pref p ON p.user_id = u.id
            WHERE u.id IN (:ids) AND u.status = 'ACTIVE'
              AND COALESCE(CASE :col WHEN 'news' THEN p.news WHEN 'announcements' THEN p.announcements
                                     WHEN 'events' THEN p.events WHEN 'messages' THEN p.messages
                                     WHEN 'communities' THEN p.communities ELSE TRUE END, TRUE)
            """, nativeQuery = true)
    List<Long> allowing(@Param("ids") Collection<Long> userIds, @Param("col") String prefColumn);
}
