package edu.bingol.backend.event.chat;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.event.extras.CoOrganizer;
import edu.bingol.backend.event.extras.CoOrganizerRepository;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Etkinlik sohbet odasi (RoomConversations, EVENT, eventId). Uyelik GOING katilimcilari + organizator + ortak
 * organizatorlerdir. Erisim yalnizca uye/organizatore aciktir, digerlerine 404 (odanin varligi sizmaz).
 * Oda etkinlik bittikten {@code app.chat.event-room-close-days} gun sonra otomatik kapanir (EventChatMaintenance).
 */
@Service("eventRoomChatService")
public class EventChatService implements EventChatHooks {

    private static final Logger log = LoggerFactory.getLogger(EventChatService.class);

    private final EventService events;
    private final RoomConversations rooms;
    private final EventRsvpRepository rsvps;
    private final UserEventRepository eventRepo;
    private final CoOrganizerRepository coOrganizers;
    private final CommunityService communities;
    private final boolean auto;
    private final int closeDays;

    public EventChatService(EventService events, RoomConversations rooms, EventRsvpRepository rsvps,
                            UserEventRepository eventRepo, CoOrganizerRepository coOrganizers,
                            CommunityService communities,
                            @Value("${app.chat.event-room-auto:false}") boolean auto,
                            @Value("${app.chat.event-room-close-days:7}") int closeDays) {
        this.events = events;
        this.rooms = rooms;
        this.rsvps = rsvps;
        this.eventRepo = eventRepo;
        this.coOrganizers = coOrganizers;
        this.communities = communities;
        this.auto = auto;
        this.closeDays = Math.max(0, closeDays);
    }

    /** conversationId yalnizca oda aciksa dolu; joined: ben su an odanin uyesi miyim. */
    public record EventChatView(Long conversationId, boolean closed, boolean joined, long memberCount) {}

    // ---- uclar ----

    /** Organizator odayi acar (yoksa kurar; kapaliysa yeniden acar). Idempotent. */
    @Transactional
    public EventChatView open(Actor a, Long eventId) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        requireOpenable(e);
        RoomInfo info = rooms.find(RoomKind.EVENT, eventId).orElse(null);
        if (info == null) {
            setUp(e);
        } else if (info.closed()) {
            rooms.openRoom(RoomKind.EVENT, eventId, memberIds(e));
        }
        if (eligible(a, e)) {
            rooms.addMembers(RoomKind.EVENT, eventId, List.of(a.id()));
        }
        return view(a, e);
    }

    /** Yalnizca uye (ya da yonetebilen organizator) gorur; digerlerine 404. */
    @Transactional(readOnly = true)
    public EventChatView get(Actor a, Long eventId) {
        UserEvent e = events.loadVisible(a, eventId);
        if (rooms.find(RoomKind.EVENT, eventId).isEmpty()
                || !(rooms.isMember(RoomKind.EVENT, eventId, a.id()) || events.canManage(a, e))) {
            throw notFound();
        }
        return view(a, e);
    }

    /** Organizator odayi kapatir (herkes cikar, gecmis saklanir) ya da yeniden acar. */
    @Transactional
    public EventChatView setClosed(Actor a, Long eventId, boolean closed) {
        if (!closed) {
            return open(a, eventId);
        }
        UserEvent e = events.requireManager(a, events.load(eventId));
        if (rooms.find(RoomKind.EVENT, eventId).isEmpty()) {
            throw notFound();
        }
        rooms.closeRoom(RoomKind.EVENT, eventId);
        return view(a, e);
    }

    /** Odadan kendi istegiyle ayrilmis (ya da eklenememis) uygun kullanicinin yeniden girmesi. */
    @Transactional
    public EventChatView join(Actor a, Long eventId) {
        UserEvent e = events.loadVisible(a, eventId);
        RoomInfo info = rooms.find(RoomKind.EVENT, eventId).orElseThrow(EventChatService::notFound);
        if (!eligible(a, e)) {
            throw notFound();
        }
        if (info.closed()) {
            throw new ApiException(HttpStatus.CONFLICT, "CHAT_ROOM_CLOSED", "Sohbet odası kapalı.");
        }
        if (!rooms.addMember(RoomKind.EVENT, eventId, a.id())) {
            throw notFound(); // hesap uygun degil (askida/dogrulanmamis)
        }
        return view(a, e);
    }

    /** Katilimci odadan ayrilir (uye degilse no-op). */
    @Transactional
    public void leave(Actor a, Long eventId) {
        events.loadVisible(a, eventId);
        if (rooms.find(RoomKind.EVENT, eventId).isEmpty()) {
            throw notFound();
        }
        rooms.removeMember(RoomKind.EVENT, eventId, a.id());
    }

    // ---- EventChatHooks ----

    @Override
    public void onGoing(Long eventId, Long userId) {
        try {
            if (rooms.find(RoomKind.EVENT, eventId).isEmpty()) {
                UserEvent e = auto ? eventRepo.findById(eventId).orElse(null) : null;
                if (e == null || e.getStatus() != UserEvent.Status.ACTIVE) {
                    return; // varsayilan: organizator acar
                }
                setUp(e);
            }
            // addMembers: oda doluysa exception yerine durur (islem rollback-only olmasin)
            rooms.addMembers(RoomKind.EVENT, eventId, List.of(userId));
        } catch (RuntimeException ex) {
            log.warn("Etkinlik odasina eklenemedi (etkinlik {}, kullanici {}): {}", eventId, userId, ex.toString());
        }
    }

    @Override
    public void onLeft(Long eventId, Long userId) {
        try {
            if (rooms.find(RoomKind.EVENT, eventId).isEmpty()) {
                return;
            }
            UserEvent e = eventRepo.findById(eventId).orElse(null);
            if (e != null && events.isOrganizer(userId, e)) {
                return; // canli organizatorler (kulup baglantisi suruyor) her zaman odada
            }
            rooms.removeMember(RoomKind.EVENT, eventId, userId);
        } catch (RuntimeException ex) {
            log.warn("Etkinlik odasindan cikarilamadi (etkinlik {}, kullanici {}): {}", eventId, userId, ex.toString());
        }
    }

    @Override
    public void onCancelled(Long eventId) {
        try {
            rooms.closeRoom(RoomKind.EVENT, eventId);
        } catch (RuntimeException ex) {
            log.warn("Etkinlik odasi kapatilamadi (etkinlik {}): {}", eventId, ex.toString());
        }
    }

    // ---- ic yardimcilar ----

    /** Odayi kurar; organizator, ortak organizatorler ve mevcut GOING katilimcilar eklenir. */
    private void setUp(UserEvent e) {
        rooms.ensureRoom(RoomKind.EVENT, e.getId(), e.getTitle(), e.getCreatedBy());
        rooms.addMembers(RoomKind.EVENT, e.getId(), memberIds(e));
    }

    private List<Long> memberIds(UserEvent e) {
        Set<Long> ids = new LinkedHashSet<>();
        ids.add(e.getCreatedBy());
        for (CoOrganizer c : coOrganizers.findByEventIdOrderById(e.getId())) {
            ids.add(c.getUserId());
        }
        for (EventRsvp r : rsvps.findByEventIdAndStatus(e.getId(), EventRsvp.Status.GOING)) {
            ids.add(r.getUserId());
        }
        return new ArrayList<>(ids);
    }

    /** Odaya girme hakki: GOING katilimci, olusturan, ortak organizator ya da bagli toplulugun etkinlik yetkilisi. */
    private boolean eligible(Actor a, UserEvent e) {
        if (events.isOrganizer(a.id(), e)) { // T-041: kulup etkinliginde olusturan/ortak organizator canli yetkiye baglidir
            return true;
        }
        if (rsvps.findByEventIdAndUserId(e.getId(), a.id()).map(r -> r.getStatus() == EventRsvp.Status.GOING).orElse(false)) {
            return true;
        }
        return e.getCommunityId() != null && communities.can(a, e.getCommunityId(), ClubPermission.MANAGE_EVENTS);
    }

    /**
     * Etkinlik detayi icin sohbet erisimi: LOCKED (etkinlik yayinda degil / sohbet suresi bitti / oda kapali ya da hic
     * kurulmamis ve yonetici degil), OPEN (odaya girebilir: GOING, olusturan, ortak organizator, kulup yetkilisi),
     * MEMBERS (katilimci olunca acilir). Yalniz tek etkinlik (detay) icin cagrilir.
     */
    @Transactional(readOnly = true)
    public String chatAccess(EventView v) {
        // Yuklu EventView'dan hesaplanir (olusturan / ortak organizator / kulup yetkilisi = canManage, GOING = myRsvp):
        // etkinligi yeniden yuklemez; tek ek sorgu oda aramasidir.
        if (v.status() != UserEvent.Status.ACTIVE || v.endsAt().plus(Duration.ofDays(closeDays)).isBefore(Instant.now())) {
            return "LOCKED";
        }
        RoomInfo info = rooms.find(RoomKind.EVENT, v.id()).orElse(null);
        if (info == null ? !v.canManage() : info.closed()) {
            return "LOCKED";
        }
        return v.canManage() || v.myRsvp() == EventRsvp.Status.GOING ? "OPEN" : "MEMBERS";
    }

    private void requireOpenable(UserEvent e) {
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_OPEN", "Etkinlik henüz yayında değil.");
        }
        if (e.getEndsAt().plus(Duration.ofDays(closeDays)).isBefore(Instant.now())) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_CHAT_ENDED",
                    "Etkinlik sohbeti etkinlik bittikten " + closeDays + " gün sonra kapanır.", String.valueOf(closeDays));
        }
    }

    private EventChatView view(Actor a, UserEvent e) {
        RoomInfo info = rooms.find(RoomKind.EVENT, e.getId()).orElseThrow(EventChatService::notFound);
        boolean joined = rooms.isMember(RoomKind.EVENT, e.getId(), a.id());
        return new EventChatView(info.closed() ? null : info.conversationId(), info.closed(), joined,
                info.closed() ? 0 : rooms.memberCount(RoomKind.EVENT, e.getId()));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CHAT_ROOM_NOT_FOUND", "Sohbet odası bulunamadı.");
    }
}
