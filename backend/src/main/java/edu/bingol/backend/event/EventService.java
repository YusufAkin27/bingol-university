package edu.bingol.backend.event;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.event.admission.EventAdmissionHooks;
import edu.bingol.backend.event.extras.CoOrganizerLookup;
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
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
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

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(EventService.class);

    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final Instant FAR_FUTURE = Instant.parse("2100-01-01T00:00:00Z");
    static final Instant MIN_DATE = Instant.parse("1970-01-01T00:00:00Z");
    static final YearMonth MIN_MONTH = YearMonth.of(2000, 1);
    static final YearMonth MAX_MONTH = YearMonth.of(2100, 1);
    static final int NOTIFY_LIMIT = 500;
    static final int CALENDAR_USER_LIMIT = 300;
    static final int CALENDAR_OFFICIAL_LIMIT = 200;
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

    /** T14: ortak organizatorler de yonetici sayilir (setter + @Lazy; null iken eski davranis). */
    private CoOrganizerLookup coOrganizers;

    @Autowired
    public void setCoOrganizers(@Lazy CoOrganizerLookup coOrganizers) {
        this.coOrganizers = coOrganizers;
    }

    /** Etkinlik sohbet odasi senkronu (setter; yoksa eski davranis). RSVP'den cikan oda disi kalir, iptalde oda kapanir. */
    private edu.bingol.backend.messaging.room.RoomConversations rooms;

    @Autowired(required = false)
    public void setRooms(edu.bingol.backend.messaging.room.RoomConversations rooms) {
        this.rooms = rooms;
    }

    private void leaveRoom(Actor a, UserEvent e) {
        if (rooms == null || canManage(a, e)) {
            return;
        }
        Long eventId = e.getId();
        Long userId = a.id();
        // Ortak transaction'da hata rollback-only birakmasin: commit sonrasi, ayri transaction'da.
        afterCommit(() -> rooms.removeMemberIsolated(edu.bingol.backend.messaging.room.RoomKind.EVENT, eventId, userId));
    }

    private void closeRoom(UserEvent e) {
        if (rooms == null) {
            return;
        }
        Long eventId = e.getId();
        afterCommit(() -> rooms.closeRoomIsolated(edu.bingol.backend.messaging.room.RoomKind.EVENT, eventId));
    }

    /**
     * Oda senkronu: islem commit olduktan sonra calisir (transaction yoksa hemen); hata yutulur ve loglanir
     * (sozlesme: senkron hatasi RSVP/iptal islemini bozmaz; sohbet erisiminde canli yetki kontrolu zaten var).
     */
    private void afterCommit(Runnable action) {
        Runnable safe = () -> {
            try {
                action.run();
            } catch (RuntimeException ex) {
                log.warn("Etkinlik odasi senkronu basarisiz: {}", ex.toString());
            }
        };
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            safe.run();
                        }
                    });
        } else {
            safe.run();
        }
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
            communities.require(a, c.getId(), ClubPermission.MANAGE_EVENTS);
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
        if (startChanged) {
            // Yeni saat icin hatirlatmalar yeniden gonderilebilsin.
            rsvps.resetReminders(e.getId());
        }
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
        if (wasActive && e.getEndsAt().isAfter(Instant.now())) {
            notifyGoing(e, "notif.event.cancelled");
        }
        if (admission != null) {
            admission.onEventCancelled(e);
        }
        closeRoom(e);
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
        Instant f = from == null ? Instant.now() : from.isBefore(MIN_DATE) ? MIN_DATE : from;
        Instant t = to == null || to.isAfter(FAR_FUTURE) ? FAR_FUTURE : to;
        List<UserEvent> rows = query(a, f, t,
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
                    Community.Status.ACTIVE, Community.Visibility.PUBLIC, CommunityMember.Status.ACTIVE,
                    PageRequest.of(0, s + 1));
        }
        return Paging.map(rows, s, UserEvent::getId, items -> views(items, a, false));
    }

    /** Takvim yaniti: ogeler + sinira (kullanici 300 / resmi 200) carpildi mi (X-Truncated basligi). */
    public record CalendarResult(List<CalendarItem> items, boolean truncated) {}

    /** Geriye uyumlu: yalnizca ogeler. */
    @Transactional(readOnly = true)
    public List<CalendarItem> calendar(Actor a, YearMonth month) {
        return calendarResult(a, month).items();
    }

    /**
     * Aylik takvim: kullanici etkinlikleri + siteden gelen resmi ETKINLIK haberleri (kaynak USER/OFFICIAL).
     * Onceki aydan suren etkinlikler de gelir; date ayin icinde kalir (baslangic ay disindaysa ayin ilk gunu).
     */
    @Transactional(readOnly = true)
    public CalendarResult calendarResult(Actor a, YearMonth month) {
        if (month.isBefore(MIN_MONTH) || month.isAfter(MAX_MONTH)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Tarih aralığı geçersiz.");
        }
        Instant from = month.atDay(1).atStartOfDay(ZONE).toInstant();
        Instant to = month.plusMonths(1).atDay(1).atStartOfDay(ZONE).toInstant();
        // Sinira carpildigini anlamak icin bir fazla satir istenir.
        List<UserEvent> userRows = query(a, from, to, 0L, null, CALENDAR_USER_LIMIT + 1);
        List<NewsItem> news = official.inRange(ContentType.ETKINLIK, month.atDay(1), month.atEndOfMonth(),
                PageRequest.of(0, CALENDAR_OFFICIAL_LIMIT + 1));
        boolean truncated = userRows.size() > CALENDAR_USER_LIMIT || news.size() > CALENDAR_OFFICIAL_LIMIT;
        List<CalendarItem> out = new ArrayList<>(calendarUserItems(a, month, firstN(userRows, CALENDAR_USER_LIMIT)));
        for (NewsItem n : firstN(news, CALENDAR_OFFICIAL_LIMIT)) {
            out.add(new CalendarItem("OFFICIAL", n.getId(), n.getTitle(),
                    n.getEventDate() != null ? n.getEventDate() : n.getPublishedDate(), null, null, null,
                    n.getUrl(), n.getImageUrl(), null, null, null, null, null, null, null));
        }
        out.sort(Comparator.comparing(CalendarItem::date, Comparator.nullsLast(Comparator.naturalOrder()))
                .thenComparing(CalendarItem::startsAt, Comparator.nullsLast(Comparator.naturalOrder())));
        return new CalendarResult(out, truncated);
    }

    private static <T> List<T> firstN(List<T> list, int n) {
        return list.size() > n ? list.subList(0, n) : list;
    }

    /** Kullanici ogeleri: RSVP, sayaclar ve topluluk adlari tek toplu sorguyla (N+1 yok). */
    private List<CalendarItem> calendarUserItems(Actor a, YearMonth month, List<UserEvent> rows) {
        if (rows.isEmpty()) {
            return List.of();
        }
        List<Long> ids = rows.stream().map(UserEvent::getId).toList();
        Map<Long, EventRsvp.Status> mine = myRsvps(a, ids);
        Map<Long, Long> interested = interestedCounts(ids);
        Map<Long, String> names = communities.namesById(
                rows.stream().map(UserEvent::getCommunityId).filter(x -> x != null).toList());
        LocalDate first = month.atDay(1);
        List<CalendarItem> out = new ArrayList<>();
        for (UserEvent e : rows) {
            LocalDate day = e.getStartsAt().atZone(ZONE).toLocalDate();
            out.add(new CalendarItem("USER", e.getId(), e.getTitle(), day.isBefore(first) ? first : day,
                    e.getStartsAt(), e.getEndsAt(), e.getLocation(), null, e.getCoverUrl(), e.getCommunityId(),
                    mine.get(e.getId()), e.getGoingCount(), interested.getOrDefault(e.getId(), 0L), e.getCapacity(),
                    e.getStatus(), e.getCommunityId() == null ? null : names.get(e.getCommunityId())));
        }
        return out;
    }

    private Map<Long, EventRsvp.Status> myRsvps(Actor a, List<Long> eventIds) {
        Map<Long, EventRsvp.Status> mine = new HashMap<>();
        rsvps.findByUserIdAndEventIdIn(a.id(), eventIds).forEach(r -> mine.put(r.getEventId(), r.getStatus()));
        return mine;
    }

    private Map<Long, Long> interestedCounts(List<Long> eventIds) {
        Map<Long, Long> out = new HashMap<>();
        for (Object[] row : rsvps.countByEvents(eventIds, EventRsvp.Status.INTERESTED)) {
            out.put((Long) row[0], ((Number) row[1]).longValue());
        }
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
            leaveRoom(a, e);
            return;
        }
        rsvps.findByEventIdAndUserId(id, a.id()).ifPresent(r -> {
            if (r.getStatus() == EventRsvp.Status.GOING) {
                events.decrementGoing(id);
            }
            rsvps.delete(r);
        });
        leaveRoom(a, e);
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
        if (coOrganizers != null && coOrganizers.isCoOrganizer(e.getId(), a.id())) {
            return true;
        }
        return e.getCommunityId() != null
                && communities.can(a, e.getCommunityId(), ClubPermission.MANAGE_EVENTS);
    }

    public UserEvent requireManager(Actor a, UserEvent e) {
        if (!canManage(a, e)) {
            // Gorunmeyen (onay bekleyen/gizli topluluk) etkinligin varligi sizmasin: once 404, gorunenlerde 403.
            ensureVisible(a, e);
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için etkinlik organizatörü olmalısınız.");
        }
        return e;
    }

    /** Yayindaki etkinlik (gizli topluluk kisitiyla) herkese; diger durumlar yalnizca organizatore, aksi halde 404. */
    public UserEvent loadVisible(Actor a, Long id) {
        return ensureVisible(a, load(id));
    }

    private UserEvent ensureVisible(Actor a, UserEvent e) {
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
        // Asiri uzak tarih veritabani zaman damgasi araligini tasirip 500 uretmesin.
        if (end.isAfter(FAR_FUTURE) || start.isBefore(MIN_DATE)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Tarih aralığı geçersiz.");
        }
    }

    // ---- ic yardimcilar ----

    private ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND", "Etkinlik bulunamadı.");
    }

    private record Cursor(Instant start, long id) {}

    /**
     * Imec = son kaydin id'si; (baslangic, id) anahtari o kayittan okunur. Kayit artik yoksa bos sayfa doner
     * (basa sarip ayni ogeleri tekrar gostermek istemciyi donguye sokar).
     */
    private Cursor cursorOf(Long cursor) {
        if (cursor == null) {
            return new Cursor(Instant.EPOCH, 0L);
        }
        return events.findById(cursor).map(e -> new Cursor(e.getStartsAt(), e.getId()))
                .orElse(new Cursor(FAR_FUTURE, Long.MAX_VALUE));
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
        Map<Long, EventRsvp.Status> mine = myRsvps(a, ids);
        Map<Long, Long> interested = detail ? interestedCounts(ids) : Map.of();
        Map<Long, String> communityNames = communities.namesById(
                list.stream().map(UserEvent::getCommunityId).filter(x -> x != null).toList());
        Map<Long, User> organizers = communities.usersById(list.stream().map(UserEvent::getCreatedBy).toList());
        Set<Long> manageable = manageableIds(list, a);
        List<EventView> out = new ArrayList<>();
        for (UserEvent e : list) {
            User o = organizers.get(e.getCreatedBy());
            out.add(new EventView(e.getId(), e.getTitle(), e.getDescription(), e.getStartsAt(), e.getEndsAt(),
                    e.getLocation(), e.getCoverUrl(), e.getCapacity(), e.getGoingCount(),
                    detail ? interested.getOrDefault(e.getId(), 0L) : null,
                    e.getCommunityId(), e.getCommunityId() == null ? null : communityNames.get(e.getCommunityId()),
                    e.getCreatedBy(),
                    o == null ? null : o.getDisplayName(), e.getStatus(), mine.get(e.getId()),
                    manageable.contains(e.getId()), e.getCreatedAt()));
        }
        return out;
    }

    /**
     * canManage kuraliyla ayni sonuc, liste icin toplu: ortak organizatorler tek sorguda, kulup yetkisi
     * kulup basina bir kez hesaplanir.
     */
    private Set<Long> manageableIds(List<UserEvent> list, Actor a) {
        Set<Long> out = new HashSet<>();
        List<UserEvent> rest = new ArrayList<>();
        for (UserEvent e : list) {
            if (a.admin() || e.getCreatedBy().equals(a.id())) {
                out.add(e.getId());
            } else {
                rest.add(e);
            }
        }
        if (rest.isEmpty()) {
            return out;
        }
        if (coOrganizers != null) {
            out.addAll(coOrganizers.coOrganizedAmong(rest.stream().map(UserEvent::getId).toList(), a.id()));
        }
        Map<Long, Boolean> clubCan = new HashMap<>();
        for (UserEvent e : rest) {
            if (!out.contains(e.getId()) && e.getCommunityId() != null
                    && clubCan.computeIfAbsent(e.getCommunityId(),
                            c -> communities.can(a, c, ClubPermission.MANAGE_EVENTS))) {
                out.add(e.getId());
            }
        }
        return out;
    }
}
