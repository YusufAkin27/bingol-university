package edu.bingol.backend.notification;

import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Kulup/etkinlik sessize alma karari. KARAR: sessize alinan kaynak kaynakli bildirimler (kulup yazisi/duyurusu,
 * etkinlik hatirlatma ve guncelleme) hem uygulama ici kutuya hem push'a GITMEZ. KRITIK olanlar sessize alma ile
 * susmaz: SYSTEM turu, etkinlik IPTALI (eventChange=CANCELLED), basvuru/kabul sonucu (EVENT_ADMISSION), kulup
 * uyelik sonucu (COMMUNITY_JOIN) ve rol/yetki bildirimi (COMMUNITY_ROLE). Kaynak, bildirim verisindeki
 * `communityId` / `eventId` anahtarindan okunur. Hata durumunda bildirim engellenmez (fail-open).
 */
@Service
public class NotificationMuteService {

    private static final Logger log = LoggerFactory.getLogger(NotificationMuteService.class);

    private final NotificationMuteRepository mutes;

    public NotificationMuteService(NotificationMuteRepository mutes) {
        this.mutes = mutes;
    }

    /** Sessize alma bu bildirimi susturabilir mi (kritik olmayan ve kaynak anahtari var). */
    static boolean mutable(NotificationType type, NotificationSubtype sub, Map<String, String> data) {
        if (data == null || type == NotificationType.SYSTEM) {
            return false;
        }
        if (sub == NotificationSubtype.EVENT_ADMISSION || sub == NotificationSubtype.COMMUNITY_JOIN
                || sub == NotificationSubtype.COMMUNITY_ROLE) {
            return false;
        }
        if ("CANCELLED".equals(data.get("eventChange"))) {
            return false;
        }
        return source(data, "communityId") != null || source(data, "eventId") != null;
    }

    private static Long source(Map<String, String> data, String key) {
        String v = data.get(key);
        if (v == null) {
            return null;
        }
        try {
            return Long.valueOf(v.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Tek alici: bu bildirim susturulmali mi. */
    public boolean isMuted(Long userId, NotificationType type, NotificationSubtype sub, Map<String, String> data) {
        return mutedAmong(List.of(userId), type, sub, data).contains(userId);
    }

    /** Alicilar arasinda bu bildirimi susturulacak olanlar (kaynak basina en fazla 2 sorgu). */
    public Set<Long> mutedAmong(Collection<Long> userIds, NotificationType type, NotificationSubtype sub,
                                Map<String, String> data) {
        if (userIds == null || userIds.isEmpty() || !mutable(type, sub, data)) {
            return Set.of();
        }
        try {
            Set<Long> out = new HashSet<>();
            Long cid = source(data, "communityId");
            if (cid != null) {
                out.addAll(mutes.mutedAmong(NotificationMute.COMMUNITY, cid, userIds));
            }
            Long eid = source(data, "eventId");
            if (eid != null) {
                out.addAll(mutes.mutedAmong(NotificationMute.EVENT, eid, userIds));
            }
            return out;
        } catch (RuntimeException e) {
            log.warn("Sessize alma denetimi basarisiz (bildirim gonderilir): {}", e.toString());
            return Set.of();
        }
    }
}
