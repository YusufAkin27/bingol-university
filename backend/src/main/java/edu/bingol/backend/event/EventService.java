package edu.bingol.backend.event;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.event.admission.EventAdmissionHooks;
import edu.bingol.backend.event.dto.EventDtos.AttendeeView;
import edu.bingol.backend.event.dto.EventDtos.CalendarItem;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.event.dto.EventDtos.RsvpResult;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import java.time.Instant;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/** Kullanici etkinlikleri: olusturma/duzenleme, RSVP (kapasite), takvim, onay akisi. */
@Service
public class EventService {

    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final Instant FAR_FUTURE = Instant.parse("2100-01-01T00:00:00Z");
    static final int NOTIFY_LIMIT = 500;
    private static final Set<String> IMAGE_TYPES = Set.of("image/jpeg", "image/png", "image/webp");
    private static final long COVER_MAX_BYTES = 3L * 1024 * 1024;

    private final UserEventRepository events;
    private final EventRsvpRepository rsvps;
    private final OfficialEventRepository official;
    private final CommunityService communities;
    private final NotificationService notifications;
    private final FileStorage storage;

    public EventService(UserEventRepository events, EventRsvpRepository rsvps, OfficialEventRepository official,
                        CommunityService communities, NotificationService notifications, FileStorage storage) {
        this.events = events;
        this.rsvps = rsvps;
        this.official = official;
        this.communities = communities;
        this.notifications = notifications;
        this.storage = storage;
    }

    /** T9: alim kurallari (setter + @Lazy: dongusel bagimlilik yok; null iken eski davranis). */
    private EventAdmissionHooks admission;

    @Autowired
    public void setAdmission(@Lazy EventAdmissionHooks admission) {
        this.admission = admission;
    }

    // ---- olusturma / guncelleme / silme ----

    /**
     * Topluluga bagliysa yalnizca MODERATOR+ olusturur ve etkinlik hemen yayindadir; bagimsizsa PENDING_REVIEW olur
     * (ADMIN olusturursa dogrudan ACTIVE).
     */
    @Transactional
    public EventView create(Actor a, CreateEventRequest r) {
        Instant now = Instant.now();
        validateDates(r.startsAt(), r.endsAt());
        if (!r.startsAt().isAfter(now)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PAST_EVENT", "Geçmişe etkinlik açılamaz.");
        }
        UserEvent e = new UserEvent();
        if (r.communityId() != null) {
            Community c = communities.load(r.communityId());
            if (c.getStatus() != Community.Status.ACTIVE) {
                throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
            }
            communities.requireModerator(a, c);
            e.setCommunityId(c.getId());
            e.setStatus(UserEvent.Status.ACTIVE);
        } else {
            if (admission != null) {
                admission.beforeCreate(a);
            }
            boolean review = !a.admin() && (admission == null || admission.requireApproval());
            e.setStatus(review ? UserEvent.Status.PENDING_REVIEW : UserEvent.Status.ACTIVE);
        }
        e.setTitle(r.title().trim());
        e.setDescription(Texts.blankToNull(r.description()));
        e.setStartsAt(r.startsAt());
        e.setEndsAt(r.endsAt());
        e.setLocation(Texts.blankToNull(r.location()));
        e.setCapacity(r.capacity());
        e.setCreatedBy(a.id());
        events.save(e);
        return views(List.of(e), a, true).get(0);
    }

    @Transactional
    public EventView update(Actor a, Long id, UpdateEventRequest r) {
        UserEvent e = load(id);
        requireManager(a, e);
        if (e.getStatus() != UserEvent.Status.ACTIVE && e.getStatus() != UserEvent.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_EDITABLE", "Bu etkinlik düzenlenemez.");
        }
        Instant now = Instant.now();
        if (e.getEndsAt().isBefore(now)) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_ENDED", "Sona ermiş etkinlik düzenlenemez.");
        }
        Instant start = r.startsAt() != null ? r.startsAt() : e.getStartsAt();
        Instant end = r.endsAt() != null ? r.endsAt() : e.getEndsAt();
        validateDates(start, end);
        boolean startChanged = !start.equals(e.getStartsAt());
        if (startChanged && !e.getStartsAt().isAfter(now)) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_STARTED", "Başlamış etkinliğin başlangıcı değiştirilemez.");
        }
        if (startChanged && !start.isAfter(now)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PAST_EVENT", "Geçmişe etkinlik açılamaz.");
        }
        if (r.capacity() != null) {
            if (r.capacity() == 0) {
                e.setCapacity(null);
            } else if (r.capacity() < e.getGoingCount()) {
                throw new ApiException(HttpStatus.CONFLICT, "CAPACITY_TOO_LOW",
                        "Kapasite, katılacak kişi sayısından (" + e.getGoingCount() + ") az olamaz.", String.valueOf(e.getGoingCount()));
            } else {
                e.setCapacity(r.capacity());
            }
        }
        boolean scheduleChanged = startChanged || !end.equals(e.getEndsAt())
                || (r.location() != null && !r.location().trim().equals(e.getLocation()));
        if (r.title() != null && !r.title().isBlank()) {
            e.setTitle(r.title().trim());
        }
        if (r.description() != null) {
            e.setDescription(Texts.blankToNull(r.description()));
        }
        if (r.location() != null) {
            e.setLocation(Texts.blankToNull(r.location()));
        }
        e.setStartsAt(start);
        e.setEndsAt(end);
        e.setUpdatedAt(now);
        events.save(e);
        if (scheduleChanged && e.getStatus() == UserEvent.Status.ACTIVE) {
            notifyGoing(e, "notif.event.updated");
        }
        if (admission != null && r.capacity() != null) {
            admission.afterCapacityChanged(e);
        }
        return views(List.of(e), a, true).get(0);
    }

    /** Silme = iptal (yumusak); katilimcilara haber verilir. */
    @Transactional
    public void delete(Actor a, Long id) {
        UserEvent e = load(id);
        requireManager(a, e);
        if (e.getStatus() == UserEvent.Status.CANCELLED) {
            return;
        }
        boolean wasActive = e.getStatus() == UserEvent.Status.ACTIVE;
        e.setStatus(UserEvent.Status.CANCELLED);
        e.setUpdatedAt(Instant.now());
        events.save(e);
        if (wasActive) {
            notifyGoing(e, "notif.event.cancelled");
        }
        if (admission != null) {
            admission.onEventCancelled(e);
        }
    }

    @Transactional
    public EventView setCover(Actor a, Long id, MultipartFile file) {
        UserEvent e = load(id);
        requireManager(a, e);
        String url = storage.save("covers", file, IMAGE_TYPES, COVER_MAX_BYTES);
        String old = e.getCoverUrl();
        e.setCoverUrl(url);
        e.setUpdatedAt(Instant.now());
        events.save(e);
        storage.delete(old);
        return views(List.of(e), a, true).get(0);
    }

    // ---- okuma ----

    /** from verilmezse simdi (bitmemis etkinlikler); to verilmezse sinirsiz. */
    @Transactional(readOnly = true)
    public CursorPage<EventView> list(Actor a, Instant from, Instant to, Long communityId, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<UserEvent> rows = query(a, from == null ? Instant.now() : from, to == null ? FAR_FUTURE : to,
                communityId == null ? 0L : communityId, cursor, s + 1);
        return Paging.map(rows, s, UserEvent::getId, items -> views(items, a, false));
    }

    @Transactional(readOnly = true)
    public EventView get(Actor a, Long id) {
        return views(List.of(loadVisible(a, id)), a, true).get(0);
    }

    /** mode: attending (RSVP'li yaklasanlar) | organizing (olusturduklarim). */
    @Transactional(readOnly = true)
    public CursorPage<EventView> mine(Actor a, String mode, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<UserEvent> rows;
        if ("organizing".equals(mode)) {
            rows = events.organizing(a.id(), UserEvent.Status.CANCELLED, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        } else {
            Cursor c = cursorOf(cursor);
            rows = events.attending(UserEvent.Status.ACTIVE, Instant.now(), c.start(), c.id(), a.id(),
                    PageRequest.of(0, s + 1));
        }
        return Paging.map(rows, s, UserEvent::getId, items -> views(items, a, false));
    }

    /** Aylik takvim: kullanici etkinlikleri + siteden gelen resmi ETKINLIK haberleri (kaynak USER/OFFICIAL). */
    @Transactional(readOnly = true)
    public List<CalendarItem> calendar(Actor a, YearMonth month) {
        Instant from = month.atDay(1).atStartOfDay(ZONE).toInstant();
        Instant to = month.plusMonths(1).atDay(1).atStartOfDay(ZONE).toInstant();
        List<CalendarItem> out = new ArrayList<>();
        for (UserEvent e : query(a, from, to, 0L, null, 300)) {
            out.add(new CalendarItem("USER", e.getId(), e.getTitle(), e.getStartsAt().atZone(ZONE).toLocalDate(),
                    e.getStartsAt(), e.getEndsAt(), e.getLocation(), null, e.getCoverUrl(), e.getCommunityId()));
        }
        for (NewsItem n : official.inRange(ContentType.ETKINLIK, month.atDay(1), month.atEndOfMonth(),
                PageRequest.of(0, 200))) {
            out.add(new CalendarItem("OFFICIAL", n.getId(), n.getTitle(), n.getPublishedDate(), null, null, null,
                    n.getUrl(), n.getImageUrl(), null));
        }
        out.sort(Comparator.comparing(CalendarItem::date, Comparator.nullsLast(Comparator.naturalOrder()))
                .thenComparing(CalendarItem::startsAt, Comparator.nullsLast(Comparator.naturalOrder())));
        return out;
    }

    // ---- RSVP ----

    /** GOING icin kapasite veritabaninda kosullu UPDATE ile atomik rezerve edilir; doluysa 409 EVENT_FULL. */
    @Transactional
    public RsvpResult rsvp(Actor a, Long id, EventRsvp.Status status) {
        UserEvent e = loadVisible(a, id);
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_OPEN", "Etkinlik henüz yayında değil.");
        }
        if (!e.getEndsAt().isAfter(Instant.now())) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_ENDED", "Etkinlik sona erdi.");
        }
        if (admission != null) {
            admission.guardDirectRsvp(e, status);
        }
        Optional<EventRsvp> existing = rsvps.findByEventIdAndUserId(id, a.id());
        if (existing.isPresent()) {
            EventRsvp r = existing.get();
            if (r.getStatus() != status) {
                if (status == EventRsvp.Status.GOING) {
                    reserveSeat(id);
                } else {
                    events.decrementGoing(id);
                }
                r.setStatus(status);
                r.setRemindedDay(false);
                r.setRemindedHour(false);
                rsvps.save(r);
            }
        } else {
            if (status == EventRsvp.Status.GOING) {
                reserveSeat(id);
            }
            try {
                rsvps.saveAndFlush(new EventRsvp(id, a.id(), status));
            } catch (DataIntegrityViolationException ex) {
                // Ayni kullanicinin es zamanli ikinci istegi; islem geri alinir, sayac da geri doner.
                throw new ApiException(HttpStatus.CONFLICT, "RSVP_CONFLICT", "İsteğiniz zaten işleniyor, tekrar deneyin.");
            }
        }
        return new RsvpResult(status, events.goingCount(id), e.getCapacity());
    }

    @Transactional
    public void cancelRsvp(Actor a, Long id) {
        UserEvent e = loadVisible(a, id);
        if (admission != null && admission.withdrawAccepted(a, e)) {
            return;
        }
        rsvps.findByEventIdAndUserId(id, a.id()).ifPresent(r -> {
            if (r.getStatus() == EventRsvp.Status.GOING) {
                events.decrementGoing(id);
            }
            rsvps.delete(r);
        });
    }

    private void reserveSeat(Long eventId) {
        if (events.tryIncrementGoing(eventId) == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_FULL", "Etkinliğin kontenjanı doldu.");
        }
    }

    /** Katilimci listesi (organizatore). status verilmezse GOING. */
    @Transactional(readOnly = true)
    public CursorPage<AttendeeView> attendees(Actor a, Long id, EventRsvp.Status status, Long cursor, int size) {
        requireManager(a, load(id));
        int s = CursorPage.clampSize(size);
        List<EventRsvp> rows = rsvps.page(id, status == null ? EventRsvp.Status.GOING : status,
                Paging.ascStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, EventRsvp::getId, items -> {
            Map<Long, User> users = communities.usersById(items.stream().map(EventRsvp::getUserId).toList());
            return items.stream().map(r -> {
                User u = users.get(r.getUserId());
                return new AttendeeView(r.getUserId(), u == null ? "Kullanıcı" : u.getDisplayName(),
                        u == null ? null : u.getAvatarUrl(), r.getStatus(), r.getCreatedAt());
            }).toList();
        });
    }

    // ---- yonetici (ADMIN) ----

    @Transactional(readOnly = true)
    public CursorPage<EventView> byStatus(UserEvent.Status status, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<UserEvent> rows = events.byStatus(status, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        Actor none = new Actor(-1L, true);
        return Paging.map(rows, s, UserEvent::getId, items -> views(items, none, false));
    }

    @Transactional
    public void review(Long id, boolean approve, String reason) {
        UserEvent e = load(id);
        if (e.getStatus() != UserEvent.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "NOT_PENDING", "Etkinlik onay beklemiyor.");
        }
        e.setStatus(approve ? UserEvent.Status.ACTIVE : UserEvent.Status.REJECTED);
        e.setReviewNote(approve ? null : Texts.blankToNull(reason));
        e.setUpdatedAt(Instant.now());
        events.save(e);
        String note = e.getReviewNote();
        notifications.sendTemplated(e.getCreatedBy(), NotificationType.EVENT,
                approve ? "notif.event.approved" : note == null ? "notif.event.rejected" : "notif.event.rejectedNote",
                Map.of("eventId", id.toString()),
                approve || note == null ? new String[] {e.getTitle()} : new String[] {e.getTitle(), note});
    }

    // ---- diger siniflarin kullandigi yardimcilar ----

    public UserEvent load(Long id) {
        return events.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND", "Etkinlik bulunamadı."));
    }

    /** Organizator mi: ADMIN, olusturan veya bagli toplulugun MODERATOR+'si. */
    public boolean canManage(Actor a, UserEvent e) {
        if (a.admin() || e.getCreatedBy().equals(a.id())) {
            return true;
        }
        return e.getCommunityId() != null
                && communities.roleOf(e.getCommunityId(), a.id()).map(CommunityMember.Role::atLeastModerator).orElse(false);
    }

    public UserEvent requireManager(Actor a, UserEvent e) {
        if (!canManage(a, e)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için etkinlik organizatörü olmalısınız.");
        }
        return e;
    }

    /** Yayindaki etkinlik (gizli topluluk kisitiyla) herkese; diger durumlar yalnizca organizatore, aksi halde 404. */
    public UserEvent loadVisible(Actor a, Long id) {
        UserEvent e = load(id);
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            if (canManage(a, e)) {
                return e;
            }
            throw notFound();
        }
        if (e.getCommunityId() != null && !a.admin()) {
            Community c = communities.load(e.getCommunityId());
            boolean member = communities.roleOf(c.getId(), a.id()).isPresent();
            if (c.getStatus() != Community.Status.ACTIVE
                    || (c.getVisibility() == Community.Visibility.PRIVATE && !member)) {
                throw notFound();
            }
        }
        return e;
    }

    static void validateDates(Instant start, Instant end) {
        if (!end.isAfter(start)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Bitiş zamanı başlangıçtan sonra olmalı.");
        }
    }

    // ---- ic yardimcilar ----

    private ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND", "Etkinlik bulunamadı.");
    }

    private record Cursor(Instant start, long id) {}

    /** Imec = son kaydin id'si; (baslangic, id) anahtari o kayittan okunur. */
    private Cursor cursorOf(Long cursor) {
        if (cursor == null) {
            return new Cursor(Instant.EPOCH, 0L);
        }
        return events.findById(cursor).map(e -> new Cursor(e.getStartsAt(), e.getId()))
                .orElse(new Cursor(Instant.EPOCH, 0L));
    }

    private List<UserEvent> query(Actor a, Instant from, Instant to, long communityId, Long cursor, int limit) {
        Cursor c = cursorOf(cursor);
        return events.upcoming(UserEvent.Status.ACTIVE, from, to, communityId, c.start(), c.id(),
                Community.Status.ACTIVE, Community.Visibility.PUBLIC, a.id(), CommunityMember.Status.ACTIVE,
                PageRequest.of(0, limit));
    }

    private void notifyGoing(UserEvent e, String key) {
        for (Long uid : rsvps.userIds(e.getId(), EventRsvp.Status.GOING, PageRequest.of(0, NOTIFY_LIMIT))) {
            if (!uid.equals(e.getCreatedBy())) {
                notifications.sendTemplated(uid, NotificationType.EVENT, key, Map.of("eventId", e.getId().toString()), e.getTitle());
            }
        }
    }

    private List<EventView> views(List<UserEvent> list, Actor a, boolean detail) {
        if (list.isEmpty()) {
            return List.of();
        }
        List<Long> ids = list.stream().map(UserEvent::getId).toList();
        Map<Long, EventRsvp.Status> mine = new HashMap<>();
        rsvps.findByUserIdAndEventIdIn(a.id(), ids).forEach(r -> mine.put(r.getEventId(), r.getStatus()));
        Map<Long, String> communityNames = new HashMap<>();
        communities.namesById(list.stream().map(UserEvent::getCommunityId).filter(x -> x != null).toList())
                .forEach(communityNames::put);
        Map<Long, User> organizers = communities.usersById(list.stream().map(UserEvent::getCreatedBy).toList());
        List<EventView> out = new ArrayList<>();
        for (UserEvent e : list) {
            User o = organizers.get(e.getCreatedBy());
            out.add(new EventView(e.getId(), e.getTitle(), e.getDescription(), e.getStartsAt(), e.getEndsAt(),
                    e.getLocation(), e.getCoverUrl(), e.getCapacity(), e.getGoingCount(),
                    detail ? rsvps.countByEventIdAndStatus(e.getId(), EventRsvp.Status.INTERESTED) : null,
                    e.getCommunityId(), communityNames.get(e.getCommunityId()), e.getCreatedBy(),
                    o == null ? null : o.getDisplayName(), e.getStatus(), mine.get(e.getId()),
                    canManage(a, e), e.getCreatedAt()));
        }
        return out;
    }
}
