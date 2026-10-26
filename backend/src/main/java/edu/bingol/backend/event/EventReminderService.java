package edu.bingol.backend.event;

import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * GOING diyen kullanicilara baslangictan ~1 gun ve ~1 saat once EVENT bildirimi. Her RSVP satirindaki
 * reminded_day/reminded_hour bayragi once "sahiplenilir" (kosullu UPDATE), sonra bildirim gider; boylece
 * ayni hatirlatma tekrar gitmez (birden fazla sunucuda da).
 */
@Service
public class EventReminderService {

    private static final Logger log = LoggerFactory.getLogger(EventReminderService.class);
    static final int BATCH = 500;

    private final EventRsvpRepository rsvps;
    private final NotificationService notifications;

    public EventReminderService(EventRsvpRepository rsvps, NotificationService notifications) {
        this.rsvps = rsvps;
        this.notifications = notifications;
    }

    @Scheduled(fixedDelayString = "${events.reminder.delay-ms:60000}", initialDelayString = "${events.reminder.initial-delay-ms:30000}")
    public void scheduled() {
        try {
            run(Instant.now());
        } catch (RuntimeException e) {
            log.warn("Etkinlik hatirlatmalari calistirilamadi: {}", e.toString());
        }
    }

    /** Dis islem yoktur: her claim* sorgusu kendi islemindedir ve bildirimden once commit olur. @return gonderilen sayi */
    public int run(Instant now) {
        int sent = 0;
        // Once saat hatirlatmalari (gun hatirlatmasi da kapanir), sonra gun hatirlatmalari.
        List<Object[]> hour = rsvps.hourCandidates(EventRsvp.Status.GOING, UserEvent.Status.ACTIVE, now,
                now.plus(Duration.ofHours(1)), PageRequest.of(0, BATCH));
        for (Object[] row : hour) {
            EventRsvp r = (EventRsvp) row[0];
            UserEvent e = (UserEvent) row[1];
            if (rsvps.claimHour(r.getId()) == 1 && send(r, e, "notif.event.reminderHour")) {
                sent++;
            }
        }
        List<Object[]> day = rsvps.dayCandidates(EventRsvp.Status.GOING, UserEvent.Status.ACTIVE,
                now.plus(Duration.ofHours(1)), now.plus(Duration.ofDays(1)), PageRequest.of(0, BATCH));
        for (Object[] row : day) {
            EventRsvp r = (EventRsvp) row[0];
            UserEvent e = (UserEvent) row[1];
            if (rsvps.claimDay(r.getId()) == 1 && send(r, e, "notif.event.reminderDay")) {
                sent++;
            }
        }
        return sent;
    }

    /** Tek kisinin hatasi digerlerinin hatirlatmasini engellemesin. */
    private boolean send(EventRsvp r, UserEvent e, String key) {
        String where = e.getLocation() == null ? "" : " (" + e.getLocation() + ")";
        try {
            notifications.sendTemplated(r.getUserId(), NotificationType.EVENT, key,
                    Map.of("eventId", e.getId().toString()), e.getTitle() + where);
            return true;
        } catch (RuntimeException ex) {
            log.warn("Hatirlatma gonderilemedi (rsvp {}): {}", r.getId(), ex.toString());
            return false;
        }
    }
}
