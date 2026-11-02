package edu.bingol.backend.event;

import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationTemplates;
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

    /**
     * Dis islem yoktur: her claim* sorgusu kendi islemindedir ve bildirimden once commit olur. FINAL-ALL: sahiplenilen
     * hatirlatmalar etkinlik basina gruplanip tek {@code sendTemplatedBulk} ile gonderilir (alici basina doSend yok);
     * gonderim istisna firlatirsa o etkinligin sahiplenmeleri geri alinir. @return sahiplenilen/gonderilen sayi
     */
    public int run(Instant now) {
        int sent = 0;
        // Once saat hatirlatmalari (gun hatirlatmasi da kapanir), sonra gun hatirlatmalari.
        List<Object[]> hour = rsvps.hourCandidates(EventRsvp.Status.GOING, UserEvent.Status.ACTIVE, now,
                now.plus(Duration.ofHours(1)), PageRequest.of(0, BATCH));
        sent += remind(hour, "notif.event.reminderHour", rsvps::claimHour, rsvps::unclaimHour);
        // FIX-P05 (A05#7, K16): "yarin" metni icin pencere daraltildi (eskiden 1-24 sa: 3 saat sonraki etkinlige de
        // "yarin" gidiyordu). Pencereye girmeyen (kisa surede RSVP verilen) etkinlik zaten saat hatirlatmasi alir.
        List<Object[]> day = rsvps.dayCandidates(EventRsvp.Status.GOING, UserEvent.Status.ACTIVE,
                now.plus(DAY_WINDOW_FROM), now.plus(DAY_WINDOW_TO), PageRequest.of(0, BATCH));
        sent += remind(day, "notif.event.reminderDay", rsvps::claimDay, rsvps::unclaimDay);
        return sent;
    }

    /** "Yarin basliyor" hatirlatmasi: baslangica 22-26 saat kala. */
    static final Duration DAY_WINDOW_FROM = Duration.ofHours(22);
    static final Duration DAY_WINDOW_TO = Duration.ofHours(26);

    /** Adaylari sahiplenir, etkinlik basina toplu gonderir; tek etkinligin hatasi digerlerini engellemez. */
    private int remind(List<Object[]> rows, String key, java.util.function.ToIntFunction<Long> claim,
                       java.util.function.Consumer<Long> unclaim) {
        Map<Long, List<Long>> claimedByEvent = new java.util.LinkedHashMap<>(); // etkinlik -> sahiplenilen rsvp kimlikleri
        Map<Long, List<Long>> usersByEvent = new java.util.LinkedHashMap<>();
        Map<Long, UserEvent> events = new java.util.HashMap<>();
        for (Object[] row : rows) {
            EventRsvp r = (EventRsvp) row[0];
            UserEvent e = (UserEvent) row[1];
            if (claim.applyAsInt(r.getId()) == 1) {
                events.putIfAbsent(e.getId(), e);
                claimedByEvent.computeIfAbsent(e.getId(), k -> new java.util.ArrayList<>()).add(r.getId());
                usersByEvent.computeIfAbsent(e.getId(), k -> new java.util.ArrayList<>()).add(r.getUserId());
            }
        }
        int sent = 0;
        for (Map.Entry<Long, List<Long>> en : usersByEvent.entrySet()) {
            UserEvent e = events.get(en.getKey());
            // Govde: "<ad> - Yarin 14:00 - <yer>" (saat Istanbul; yer yoksa son parca yok)
            String time = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
                    .format(e.getStartsAt().atZone(java.time.ZoneId.of("Europe/Istanbul")));
            String where = e.getLocation() == null || e.getLocation().isBlank() ? "" : " · " + e.getLocation().trim();
            try {
                notifications.sendTemplatedBulk(en.getValue(), NotificationTemplates.of(key, NotificationType.EVENT),
                        Map.of("eventId", e.getId().toString()), null, e.getTitle(), time, where);
                sent += en.getValue().size();
            } catch (RuntimeException ex) {
                log.warn("Hatirlatma gonderilemedi (etkinlik {}, {} alici): {}", e.getId(), en.getValue().size(), ex.toString());
                // FIX-P05: gonderim hatasinda iz geri alinir, sonraki turda yeniden denenir
                claimedByEvent.get(en.getKey()).forEach(unclaim);
            }
        }
        return sent;
    }
}
