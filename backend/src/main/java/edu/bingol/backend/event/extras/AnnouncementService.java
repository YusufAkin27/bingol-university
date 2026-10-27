package edu.bingol.backend.event.extras;

import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.extras.ExtrasDtos.AnnouncementResult;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Organizatorden katilimcilara (GOING; kabul edilmis basvurular da GOING'dir) toplu duyuru. */
@Service
public class AnnouncementService {

    static final int DAILY_LIMIT = 3;
    static final int MAX_RECIPIENTS = 1000;
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private final EventService events;
    private final EventRsvpRepository rsvps;
    private final EventAnnouncementRepository log;
    private final CommunityService communities;
    private final BlockService blocks;
    private final NotificationService notifications;

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    public AnnouncementService(EventService events, EventRsvpRepository rsvps, EventAnnouncementRepository log,
                               CommunityService communities, BlockService blocks, NotificationService notifications) {
        this.events = events;
        this.rsvps = rsvps;
        this.log = log;
        this.communities = communities;
        this.blocks = blocks;
        this.notifications = notifications;
    }

    public AnnouncementResult send(Actor a, Long eventId, String title, String message, Instant now) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_OPEN", "Etkinlik henüz yayında değil.");
        }
        if (!e.getEndsAt().isAfter(now)) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_ENDED", "Etkinlik sona erdi.");
        }
        Instant dayStart = now.atZone(ZONE).toLocalDate().atStartOfDay(ZONE).toInstant();
        long used = log.countByEventIdAndCreatedAtGreaterThanEqual(eventId, dayStart);
        if (used >= DAILY_LIMIT) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "ANNOUNCEMENT_LIMIT",
                    "Bir etkinlik için günde en fazla " + DAILY_LIMIT + " duyuru gönderilebilir.", String.valueOf(DAILY_LIMIT));
        }
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "title", a.id(), title);
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "message", a.id(), message);
        List<Long> ids = rsvps.userIds(eventId, EventRsvp.Status.GOING, PageRequest.of(0, MAX_RECIPIENTS));
        Map<Long, User> users = communities.usersById(ids);
        int sent = 0;
        String t = title.trim();
        String m = message.trim();
        // Kayit once yazilir: es zamanli isteklerde bile hak tuketilir (sinir asilamaz hale gelmez).
        EventAnnouncement rec = new EventAnnouncement();
        rec.setEventId(eventId);
        rec.setSenderId(a.id());
        rec.setCreatedAt(now);
        log.save(rec);
        for (Long uid : ids) {
            User u = users.get(uid);
            if (uid.equals(a.id()) || u == null || u.getStatus() != UserStatus.ACTIVE || blocks.isBlocked(a.id(), uid)) {
                continue;
            }
            notifications.sendTemplate(uid, ExtrasTemplates.ANNOUNCEMENT, Map.of("eventId", eventId.toString()),
                    null, e.getTitle(), t, m);
            sent++;
        }
        rec.setRecipients(sent);
        log.save(rec);
        return new AnnouncementResult(sent, (int) (DAILY_LIMIT - used - 1));
    }
}
