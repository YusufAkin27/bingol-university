package edu.bingol.backend.event;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Yoklama okutma olaylarini gercek zamanli yayinlar (`/user/queue/attendance-events`, ChatEventBus + Redis pub/sub).
 * Alicilar yalnizca ILGILI kisilerdir: etkinlik sahibi + yoklama yetkili moderatorler ({@code SCAN}: sayac + son
 * okutan) ve okutulan katilimcinin kendisi ({@code MARKED}). Yayin commit SONRASI yapilir; hata yoklamayi bozmaz.
 * Pub/sub kalici degildir: istemci yedek olarak `/attendance/summary` ve `/my-attendance` uclarini yoklar; ayni
 * okutma icin {@code key} sabittir (istemci cift olayi eler).
 */
@Component
public class AttendanceLiveEvents {

    static final String DEST = "attendance-events";
    private static final Logger log = LoggerFactory.getLogger(AttendanceLiveEvents.class);

    /** type: SCAN (yetkililere) | MARKED (okutulan katilimciya). present/total yalniz SCAN'de anlamli. */
    public record Payload(String type, String key, Long eventId, Long userId, String displayName, Instant at,
                          long present, long total) {
    }

    private final ChatEventBus bus;
    private final EventAttendanceRepository attendance;
    private final EventRsvpRepository rsvps;
    private final EventModeratorRepository mods;
    private final EventModeratorService moderators;
    private final CommunityService communities;

    public AttendanceLiveEvents(ChatEventBus bus, EventAttendanceRepository attendance, EventRsvpRepository rsvps,
                                EventModeratorRepository mods, @Lazy EventModeratorService moderators,
                                CommunityService communities) {
        this.bus = bus;
        this.attendance = attendance;
        this.rsvps = rsvps;
        this.mods = mods;
        this.moderators = moderators;
        this.communities = communities;
    }

    /** Yeni QR okutmasi sonrasi (yalniz yeni kayitta cagrilir; "zaten okutulmus" yayin uretmez). */
    public void scanned(UserEvent e, Long userId, String displayName, Instant at) {
        afterCommit(() -> {
            String key = e.getId() + ":" + userId + ":" + at.toEpochMilli();
            long present = attendance.countByEventIdAndPresentTrue(e.getId());
            long total = rsvps.countByEventIdAndStatus(e.getId(), EventRsvp.Status.GOING);
            for (Long staff : staffOf(e)) {
                // Engel iliskisi olan cift: ad gizlenir (liste kurali ile ayni), sayac yine gider.
                boolean hide = !staff.equals(userId) && communities.blockedFor(new Actor(staff, false)).contains(userId);
                bus.publish(DEST, Set.of(staff),
                        new Payload("SCAN", key, e.getId(), hide ? null : userId, hide ? null : displayName, at, present, total));
            }
            bus.publish(DEST, Set.of(userId), new Payload("MARKED", key, e.getId(), userId, null, at, 0, 0));
        });
    }

    /** Sahip + TAKE/VIEW yetkili moderatorler. */
    Set<Long> staffOf(UserEvent e) {
        Set<Long> out = new LinkedHashSet<>();
        if (e.getCreatedBy() != null) {
            out.add(e.getCreatedBy());
        }
        for (EventModerator m : mods.findByEventIdOrderByCreatedAtAsc(e.getId())) {
            if (moderators.has(e, m.getUserId(), EventModerator.Perm.TAKE_ATTENDANCE)
                    || moderators.has(e, m.getUserId(), EventModerator.Perm.VIEW_ATTENDEES)) {
                out.add(m.getUserId());
            }
        }
        return out;
    }

    private static void afterCommit(Runnable r) {
        Runnable safe = () -> {
            try {
                r.run();
            } catch (RuntimeException ex) {
                log.warn("Yoklama olayi yayinlanamadi: {}", ex.toString());
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    safe.run();
                }
            });
        } else {
            safe.run();
        }
    }
}
