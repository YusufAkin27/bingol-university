package edu.bingol.backend.event;

import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.event.admission.EventAdmissionHooks;
import edu.bingol.backend.event.chat.EventChatHooks;
import edu.bingol.backend.event.extras.CoOrganizerLookup;
import edu.bingol.backend.event.dto.EventDtos;
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

    // Yazma yolundaki sinirlar (V550 oncesi kayitlar etkilenmez: yalniz olusturma/degisen alan denetlenir).
    @org.springframework.beans.factory.annotation.Value("${app.event.max-title-length:100}")
    private int maxTitleLength = 100;
    @org.springframework.beans.factory.annotation.Value("${app.event.max-description-length:1000}")
    private int maxDescriptionLength = 1000;
    @org.springframework.beans.factory.annotation.Value("${app.event.max-location-length:120}")
    private int maxLocationLength = 120;
    @org.springframework.beans.factory.annotation.Value("${app.event.max-duration-days:30}")
    private int maxDurationDays = 30;
    static final int CALENDAR_USER_LIMIT = 300;
    static final int CALENDAR_OFFICIAL_LIMIT = 200;

    private final UserEventRepository events;
    private final EventRsvpRepository rsvps;
    private final OfficialEventRepository official;
    private final CommunityService communities;
    private final NotificationService notifications;
    private final MediaService media;

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    public EventService(UserEventRepository events, EventRsvpRepository rsvps, OfficialEventRepository official,
                        CommunityService communities, NotificationService notifications, MediaService media) {
        this.events = events;
        this.rsvps = rsvps;
        this.official = official;
        this.communities = communities;
        this.notifications = notifications;
        this.media = media;
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

    /** T25: etkinlik sohbet odasi senkronu (setter + @Lazy; null iken eski davranis). */
    private EventChatHooks chat;

    @Autowired
    public void setChat(@Lazy EventChatHooks chat) {
        this.chat = chat;
    }

    // ---- olusturma / guncelleme / silme ----

    /**
     * Yalnizca kulup adina (communityId zorunlu, yoksa 400 EVENT_CLUB_REQUIRED). MODERATOR+ ve sistem ADMIN'i dogrudan
     * ACTIVE; MANAGE_EVENTS verilmis sade uye PENDING_REVIEW (yonetici onayi); izni olmayan 403.
     */
    @Transactional
    public EventView create(Actor a, CreateEventRequest r) {
        Instant now = Instant.now();
        validateDates(r.startsAt(), r.endsAt());
        validateDuration(r.startsAt(), r.endsAt());
        if (!r.startsAt().isAfter(now)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PAST_EVENT", "Geçmişe etkinlik açılamaz.");
        }
        validateTexts(r.title(), r.description(), r.location());
        if (r.title().trim().length() < 3) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Başlık en az 3 karakter olmalı.");
        }
        // Kulup zorunlu: bagimsiz (kulupsuz) etkinlik acilamaz (mevcut kulupsuz kayitlar etkilenmez).
        if (r.communityId() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EVENT_CLUB_REQUIRED", "Etkinlik bir kulüp adına açılmalıdır.");
        }
        ContentGuard.clean(guard, Entity.EVENT, "title", a.id(), r.title());
        ContentGuard.clean(guard, Entity.EVENT, "description", a.id(), r.description());
        ContentGuard.clean(guard, Entity.EVENT, "location", a.id(), r.location());
        UserEvent e = new UserEvent();
        Community c = communities.load(r.communityId());
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
        }
        // MANAGE_EVENTS yoksa 403. Yonetici/yetkili (MODERATOR+, sistem ADMIN'i) dogrudan yayinda; ozel yetki verilmis
        // sade uye (ornek: EVENT_MANAGER sablonu) yonetici onayina gider.
        communities.require(a, c.getId(), ClubPermission.MANAGE_EVENTS);
        e.setCommunityId(c.getId());
        boolean staff = a.admin() || communities.roleOf(c.getId(), a.id())
                .map(role -> role != CommunityMember.Role.MEMBER).orElse(false);
        e.setStatus(staff ? UserEvent.Status.ACTIVE : UserEvent.Status.PENDING_REVIEW);
        e.setTitle(r.title().trim());
        e.setDescription(Texts.blankToNull(r.description()));
        e.setStartsAt(r.startsAt());
        e.setEndsAt(r.endsAt());
        e.setLocation(Texts.blankToNull(r.location()));
        e.setCapacity(r.capacity());
        e.setCreatedBy(a.id());
        events.save(e);
        if (r.joinPolicy() != null && r.joinPolicy() != edu.bingol.backend.event.admission.EventAdmission.Mode.OPEN
                && admission != null) {
            admission.applyJoinPolicy(e, r.joinPolicy());
        }
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
        ContentGuard.changed(guard, Entity.EVENT, "title", a.id(), e.getTitle(), r.title());
        ContentGuard.changed(guard, Entity.EVENT, "description", a.id(), e.getDescription(), r.description());
        ContentGuard.changed(guard, Entity.EVENT, "location", a.id(), e.getLocation(), r.location());
        Instant start = r.startsAt() != null ? r.startsAt() : e.getStartsAt();
        Instant end = r.endsAt() != null ? r.endsAt() : e.getEndsAt();
        validateDates(start, end);
        if (r.startsAt() != null || r.endsAt() != null) {
            validateDuration(start, end);
        }
        // Metin sinirlari yalniz DEGISEN alana uygulanir (eski, sinirdan uzun kayit bozulmadan yeniden kaydedilebilir).
        validateTexts(changed(r.title(), e.getTitle()), changed(r.description(), e.getDescription()),
                changed(r.location(), e.getLocation()));
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
        if (r.joinPolicy() != null && admission != null) {
            admission.applyJoinPolicy(e, r.joinPolicy());
        }
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
        cancelInternal(e);
    }

    /** Kayitlari kapatir/yeniden acar (idempotent): kapaliyken yeni RSVP/basvuru 409 EVENT_REGISTRATION_CLOSED olur. */
    @Transactional
    public EventView setRegistrationClosed(Actor a, Long id, boolean closed) {
        UserEvent e = load(id);
        requireManager(a, e);
        requireCoverEditable(e); // ACTIVE / PENDING_REVIEW disinda 409 EVENT_NOT_EDITABLE
        if (e.getEndsAt().isBefore(Instant.now())) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_ENDED", "Sona ermiş etkinlik düzenlenemez.");
        }
        if (e.isRegistrationClosed() != closed) {
            e.setRegistrationClosed(closed);
            e.setUpdatedAt(Instant.now());
            events.save(e);
        }
        return views(List.of(e), a, true).get(0);
    }

    /** Kulup silinince: kulubun bitmemis, yayindaki/onay bekleyen etkinlikleri iptal edilir (katilimcilara haber gider). */
    @Transactional
    public int cancelForDeletedClub(Long communityId) {
        int n = 0;
        for (Long eventId : events.liveIdsByCommunity(communityId,
                List.of(UserEvent.Status.ACTIVE, UserEvent.Status.PENDING_REVIEW), Instant.now())) {
            events.findById(eventId).ifPresent(this::cancelInternal);
            n++;
        }
        return n;
    }

    /**
     * Hesabi silinen organizatorun kulube bagli olmayan, bitmemis etkinlikleri iptal edilir (yonetecek kimse kalmaz;
     * katilimcilara haber gider). Kulup etkinlikleri kulup yetkililerinde kalir.
     */
    @Transactional
    public int cancelForDeletedOrganizer(Long userId) {
        int n = 0;
        for (Long eventId : events.liveIdsByOrganizer(userId,
                List.of(UserEvent.Status.ACTIVE, UserEvent.Status.PENDING_REVIEW), Instant.now())) {
            events.findById(eventId).ifPresent(this::cancelInternal);
            n++;
        }
        return n;
    }

    private void cancelInternal(UserEvent e) {
        cancelInternal(e, e.getStatus() == UserEvent.Status.ACTIVE);
    }

    /**
     * Yonetici iptali (EventModerationService): ACTIVE/HIDDEN etkinlikte katilimcilara ve istek sahiplerine iptal
     * bildirimi gider (gizliyken katilimcilar gizlemeden haberdar edilmemisti, iptalde haberdar edilir);
     * PENDING_REVIEW'de katilimci yoktur. Sohbet odasi kapanir, hatirlatmalar ACTIVE disinda zaten durur.
     */
    void cancelByModerator(UserEvent e) {
        cancelInternal(e, e.getStatus() == UserEvent.Status.ACTIVE || e.getStatus() == UserEvent.Status.HIDDEN);
    }

    private void cancelInternal(UserEvent e, boolean wasActive) {
        if (e.getStatus() == UserEvent.Status.CANCELLED) {
            return;
        }
        e.setStatus(UserEvent.Status.CANCELLED);
        e.setUpdatedAt(Instant.now());
        String oldCover = e.getCoverUrl();
        e.setCoverUrl(null);
        events.saveAndFlush(e);
        media.release(oldCover);
        if (wasActive && e.getEndsAt().isAfter(Instant.now())) {
            notifyGoing(e, "notif.event.cancelled");
        }
        if (admission != null) {
            admission.onEventCancelled(e);
        }
        closeRoom(e);
        if (chat != null) {
            chat.onCancelled(e.getId());
        }
    }

    /** Kapak: medya hatti (dogrula, yeniden kodla, EXIF temizle, en cok 1600 px); eski dosya referans yoksa silinir. */
    @Transactional
    public EventView setCover(Actor a, Long id, MultipartFile file) {
        UserEvent e = load(id);
        requireManager(a, e);
        requireCoverEditable(e);
        String url = media.storeImage(file, ImageKind.COVER).url();
        String old = e.getCoverUrl();
        e.setCoverUrl(url);
        e.setUpdatedAt(Instant.now());
        events.saveAndFlush(e);
        if (old != null && !old.equals(url)) {
            media.release(old);
        }
        return views(List.of(e), a, true).get(0);
    }

    /** Kapagi kaldirir (idempotent). */
    @Transactional
    public void removeCover(Actor a, Long id) {
        UserEvent e = load(id);
        requireManager(a, e);
        String old = e.getCoverUrl();
        if (old != null) {
            e.setCoverUrl(null);
            e.setUpdatedAt(Instant.now());
            events.saveAndFlush(e);
            media.release(old);
        }
    }

    private static void requireCoverEditable(UserEvent e) {
        if (e.getStatus() != UserEvent.Status.ACTIVE && e.getStatus() != UserEvent.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_EDITABLE", "Bu etkinlik düzenlenemez.");
        }
    }

    /**
     * Ana sayfa ogesi: yaklasan (ya da suren) ACTIVE kullanici etkinlikleri icinde en cok GOING'e sahip olan;
     * esitlikte baslangici yakin olan. Yoksa bos. Resmi (siteden gelen) etkinlikler dahil degildir.
     */
    @Transactional(readOnly = true)
    public Optional<EventView> featured(Actor a) {
        List<UserEvent> rows = events.featured(UserEvent.Status.ACTIVE, Instant.now(),
                Community.Status.ACTIVE, Community.Visibility.PUBLIC, a.id(), CommunityMember.Status.ACTIVE,
                PageRequest.of(0, 1));
        return rows.isEmpty() ? Optional.empty() : Optional.of(views(rows, a, false).get(0));
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

    /**
     * Etkinliklerim. mode: upcoming (yaklasan: RSVP'li + olusturduklarim) | going (yaklasan, yalniz GOING) |
     * past (bitmis: RSVP'li + olusturduklarim, yeniden eskiye) | created (olusturduklarim, iptaller haric) |
     * attending (eski: yaklasan RSVP'liler; varsayilan, bilinmeyen modlar da) | organizing (created'in eski adi).
     * Imec = son kaydin id'si.
     */
    @Transactional(readOnly = true)
    public CursorPage<EventView> mine(Actor a, String mode, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<UserEvent> rows;
        String m = mode == null ? "attending" : mode;
        if ("organizing".equals(m) || "created".equals(m)) {
            rows = events.organizing(a.id(), UserEvent.Status.CANCELLED, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        } else if ("upcoming".equals(m) || "going".equals(m)) {
            Cursor c = cursorOf(cursor);
            rows = events.mineUpcoming(UserEvent.Status.ACTIVE, Instant.now(), c.start(), c.id(), a.id(),
                    "upcoming".equals(m), "going".equals(m), EventRsvp.Status.GOING,
                    Community.Status.ACTIVE, Community.Visibility.PUBLIC, CommunityMember.Status.ACTIVE,
                    PageRequest.of(0, s + 1));
        } else if ("past".equals(m)) {
            Cursor c = cursor == null ? new Cursor(FAR_FUTURE, Long.MAX_VALUE)
                    : events.findById(cursor).map(e -> new Cursor(e.getStartsAt(), e.getId()))
                            .orElse(new Cursor(MIN_DATE, 0L)); // kayit yoksa bos sayfa (basa sarma yok)
            rows = events.minePast(UserEvent.Status.ACTIVE, Instant.now(), c.start(), c.id(), a.id(),
                    Community.Status.ACTIVE, Community.Visibility.PUBLIC, CommunityMember.Status.ACTIVE,
                    PageRequest.of(0, s + 1));
        } else { // attending ve bilinmeyen modlar (eski davranis)
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
        if (admission != null) { // bekleyen/reddedilen katilim istegi GOING olmayan her durumun onune gecer
            admission.requestStates(a.id(), eventIds).forEach((eid, st) -> {
                if (mine.get(eid) != EventRsvp.Status.GOING) {
                    mine.put(eid, st);
                }
            });
        }
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
        if (status != EventRsvp.Status.GOING && status != EventRsvp.Status.INTERESTED) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz katılım durumu.");
        }
        Optional<EventRsvp> existing = rsvps.findByEventIdAndUserId(id, a.id());
        // Kayit kapaliyken yeni katilim yok; mevcut RSVP'si olan geri cekilebilir / ilgiye dusebilir ama GOING'e gecemez.
        if (e.isRegistrationClosed() && (existing.isEmpty()
                || (status == EventRsvp.Status.GOING && existing.get().getStatus() != EventRsvp.Status.GOING))) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_REGISTRATION_CLOSED", "Bu etkinliğin kayıtları kapatıldı.");
        }
        // APPROVAL: GOING dogrudan katilim degil katilim istegidir (PENDING); kabul edilmis GOING aynen kalir.
        if (status == EventRsvp.Status.GOING && admission != null
                && !(existing.isPresent() && existing.get().getStatus() == EventRsvp.Status.GOING)
                && admission.requestIfApprovalRequired(a, e)) {
            return new RsvpResult(EventRsvp.Status.PENDING, events.goingCount(id), e.getCapacity());
        }
        if (existing.isPresent()) {
            EventRsvp r = existing.get();
            if (r.getStatus() != status) {
                if (status == EventRsvp.Status.GOING) {
                    reserveSeat(id);
                } else {
                    events.decrementGoing(id);
                }
                EventRsvp.Status old = r.getStatus();
                r.setStatus(status);
                rsvps.save(r);
                chatSync(id, a.id(), old, status);
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
            chatSync(id, a.id(), null, status);
        }
        return new RsvpResult(status, events.goingCount(id), e.getCapacity());
    }

    @Transactional
    public void cancelRsvp(Actor a, Long id) {
        UserEvent e = loadVisible(a, id);
        if (admission != null && admission.withdrawAccepted(a, e)) {
            // Istek geri cekildi / koltuk birakildi; kalan ilgileniyorum kaydi da silinir.
            rsvps.findByEventIdAndUserId(id, a.id()).filter(r -> r.getStatus() != EventRsvp.Status.GOING).ifPresent(rsvps::delete);
            leaveRoom(a, e);
            return;
        }
        rsvps.findByEventIdAndUserId(id, a.id()).ifPresent(r -> {
            if (r.getStatus() == EventRsvp.Status.GOING) {
                events.decrementGoing(id);
            }
            rsvps.delete(r);
            chatSync(id, a.id(), r.getStatus(), null);
        });
        leaveRoom(a, e);
    }

    /** GOING girisi/cikisi sohbet odasina yansir (hook yoksa no-op). */
    private void chatSync(Long eventId, Long userId, EventRsvp.Status from, EventRsvp.Status to) {
        if (chat == null) {
            return;
        }
        if (to == EventRsvp.Status.GOING) {
            chat.onGoing(eventId, userId);
        } else if (from == EventRsvp.Status.GOING) { // yalnizca GOING odada kalir (INTERESTED'a dusen de cikar)
            chat.onLeft(eventId, userId);
        }
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
        Set<Long> hideAvatar = communities.blockedFor(a); // engel iliskisi olanin avatari gorunmez
        return Paging.map(rows, s, EventRsvp::getId, items -> {
            Map<Long, User> users = communities.usersById(items.stream().map(EventRsvp::getUserId).toList());
            return items.stream().map(r -> {
                User u = users.get(r.getUserId());
                return new AttendeeView(r.getUserId(), u == null ? "Kullanıcı" : u.getDisplayName(),
                        u == null || hideAvatar.contains(r.getUserId()) ? null : u.getAvatarUrl(), r.getStatus(), r.getCreatedAt());
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

    /** Yonetici gorunumu: gorunurluk/yetki kisiti yok; pendingCount tum etkinlikler icin dolu (ADMIN her etkinligi yonetir). */
    @Transactional(readOnly = true)
    public List<EventView> adminViews(List<UserEvent> rows, boolean detail) {
        return views(rows, new Actor(-1L, true), detail);
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
        // Yonetici gizledigi etkinlik organizatore de gorunmez (gizleme yonetici islemidir).
        if (e.getStatus() == UserEvent.Status.HIDDEN && !a.admin()) {
            throw notFound();
        }
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
            // HIDDEN: yalnizca yoneticiye gorunur (organizator dahil herkese 404).
            if ((e.getStatus() != UserEvent.Status.HIDDEN || a.admin()) && canManage(a, e)) {
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

    /** Gonderilen metin mevcutla (kirpilmis) ayniysa null: o alan yeniden denetlenmez. */
    private static String changed(String incoming, String existing) {
        if (incoming == null) {
            return null;
        }
        String t = incoming.trim();
        return t.equals(existing == null ? "" : existing) ? null : incoming;
    }

    /** Baslik/aciklama/yer ust sinirlari (kirpilmis uzunluk); null alan atlanir. */
    void validateTexts(String title, String description, String location) {
        if (title != null && title.trim().length() > maxTitleLength) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EVENT_TITLE_TOO_LONG",
                    "Başlık en fazla " + maxTitleLength + " karakter olabilir.", String.valueOf(maxTitleLength));
        }
        if (description != null && description.trim().length() > maxDescriptionLength) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EVENT_DESCRIPTION_TOO_LONG",
                    "Açıklama en fazla " + maxDescriptionLength + " karakter olabilir.",
                    String.valueOf(maxDescriptionLength));
        }
        if (location != null && location.trim().length() > maxLocationLength) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EVENT_LOCATION_TOO_LONG",
                    "Yer en fazla " + maxLocationLength + " karakter olabilir.", String.valueOf(maxLocationLength));
        }
    }

    /** Bitis baslangictan SONRA olmali (esitlik gecersiz); asiri tarihler reddedilir. */
    static void validateDates(Instant start, Instant end) {
        if (!end.isAfter(start)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Bitiş zamanı başlangıçtan sonra olmalı.");
        }
        // Asiri uzak tarih veritabani zaman damgasi araligini tasirip 500 uretmesin.
        if (end.isAfter(FAR_FUTURE) || start.isBefore(MIN_DATE)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Tarih aralığı geçersiz.");
        }
    }

    /** Bitis baslangictan en cok maxDurationDays gun sonra (yalniz tarih yazilirken; eski uzun kayitlar etkilenmez). */
    void validateDuration(Instant start, Instant end) {
        if (java.time.Duration.between(start, end).compareTo(java.time.Duration.ofDays(maxDurationDays)) > 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EVENT_TOO_LONG",
                    "Etkinlik en fazla " + maxDurationDays + " gün sürebilir.", String.valueOf(maxDurationDays));
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
        Map<Long, edu.bingol.backend.event.admission.EventAdmission.Mode> policies =
                admission == null ? new HashMap<>() : new HashMap<>(admission.joinPolicies(ids));
        Map<Long, Long> pending = admission == null || manageable.isEmpty() ? new HashMap<>()
                : new HashMap<>(admission.pendingCounts(manageable));
        Set<Long> hideAvatar = communities.blockedFor(a); // engel iliskisi olanin avatari gorunmez
        List<EventView> out = new ArrayList<>();
        for (UserEvent e : list) {
            User o = organizers.get(e.getCreatedBy());
            out.add(new EventView(e.getId(), e.getTitle(), e.getDescription(), e.getStartsAt(), e.getEndsAt(),
                    e.getLocation(), e.getCoverUrl(), e.getCapacity(), e.getGoingCount(),
                    detail ? interested.getOrDefault(e.getId(), 0L) : null,
                    e.getCommunityId(), e.getCommunityId() == null ? null : communityNames.get(e.getCommunityId()),
                    e.getCreatedBy(),
                    o == null ? null : o.getDisplayName(), e.getStatus(), mine.get(e.getId()),
                    manageable.contains(e.getId()), e.getCreatedAt(), e.isRegistrationClosed(),
                    policies.getOrDefault(e.getId(), edu.bingol.backend.event.admission.EventAdmission.Mode.OPEN),
                    new EventDtos.OrganizerView(e.getCreatedBy(), o == null ? null : o.getDisplayName(),
                            o == null || hideAvatar.contains(e.getCreatedBy()) ? null : o.getAvatarUrl()),
                    manageable.contains(e.getId()) ? pending.getOrDefault(e.getId(), 0L) : null));
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
