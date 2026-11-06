package edu.bingol.backend.event;

import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.notification.PushDisplay;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Etkinlik bildirimlerinin kart alanlari (docs/changes/push.md "Bildirim tasarimi yuk sozlesmesi"): kulup adi
 * (`sourceName`, yalniz push), baslangic ani (`eventStartsAt`), yer (`location`), rozet ve saat revizesi. Veri yoksa
 * anahtar konmaz; hata bildirimi bozmaz.
 */
@Component
public class EventPushHints {

    private final CommunityRepository communities;

    public EventPushHints(CommunityRepository communities) {
        this.communities = communities;
    }

    /** Temel: eventId + kulup adi + baslangic + yer. */
    public Map<String, String> of(UserEvent e) {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("eventId", String.valueOf(e.getId()));
        try {
            if (e.getCommunityId() != null) {
                communities.findById(e.getCommunityId())
                        .ifPresent(c -> PushDisplay.put(d, "sourceName", c.getName(), 60));
            }
        } catch (RuntimeException ignored) {
            // kaynak adi istege bagli
        }
        PushDisplay.put(d, "eventStartsAt", PushDisplay.iso(e.getStartsAt()), 32);
        PushDisplay.put(d, "location", e.getLocation(), 80);
        PushDisplay.put(d, "meetingPoint", e.getMeetingPoint(), 80);
        return d;
    }

    /** "Yarin basliyor" hatirlatmasi. */
    public Map<String, String> tomorrow(UserEvent e) {
        Map<String, String> d = of(e);
        d.put("badgeKey", PushDisplay.BADGE_TOMORROW);
        return d;
    }

    /** Zaman/yer degisti: baslangic saati degistiyse eski/yeni saat + "Saat Revizesi". */
    public Map<String, String> updated(UserEvent e, Instant oldStartsAt) {
        Map<String, String> d = of(e);
        if (oldStartsAt != null && e.getStartsAt() != null && !oldStartsAt.equals(e.getStartsAt())) {
            d.put("oldStartsAt", PushDisplay.iso(oldStartsAt));
            d.put("newStartsAt", PushDisplay.iso(e.getStartsAt()));
            d.put("badgeKey", PushDisplay.BADGE_TIME_REVISION);
        }
        d.put("eventChange", oldStartsAt != null && !oldStartsAt.equals(e.getStartsAt()) ? "TIME" : "PLACE");
        return d;
    }

    /** Iptal. */
    public Map<String, String> cancelled(UserEvent e) {
        Map<String, String> d = of(e);
        d.put("badgeKey", PushDisplay.BADGE_CANCELLED);
        d.put("eventChange", "CANCELLED");
        return d;
    }
}
