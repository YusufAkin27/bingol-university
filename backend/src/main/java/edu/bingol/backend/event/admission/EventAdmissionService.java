package edu.bingol.backend.event.admission;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.admission.AdmissionDtos.Action;
import edu.bingol.backend.event.admission.AdmissionDtos.AdmissionSummary;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplicantView;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplicationView;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplyRequest;
import edu.bingol.backend.event.admission.AdmissionDtos.ConfigRequest;
import edu.bingol.backend.event.admission.AdmissionDtos.ConfigView;
import edu.bingol.backend.event.admission.AdmissionDtos.DecisionItem;
import edu.bingol.backend.event.admission.AdmissionDtos.DecisionResult;
import edu.bingol.backend.event.admission.EventAdmission.Mode;
import edu.bingol.backend.event.chat.EventChatHooks;
import edu.bingol.backend.event.admission.EventApplication.Status;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Etkinlik katilim yonetimi. APPROVAL modunda: basvuru (PENDING) -> organizator kabul/ret/bekleme. Kabul = bir koltuk
 * (user_event.going_count) + GOING RSVP; boylece QR/elle yoklama, hatirlatma ve katilimci listesi mevcut yolla calisir.
 * Kontenjan doluyken kabul edilen basvuru WAITLISTED olur; yer acilinca (vazgecme, cikarma, kapasite artisi)
 * bekleme listesinin basindaki otomatik terfi eder.
 *
 * <p>Yaris guvenligi: her degistirici islem once etkinlik satirini kilitler (FOR UPDATE), sonra basvurulari okur;
 * boylece ayni etkinlikteki islemler sirayla yurur, sira (queued_at, id) ve kapasite bozulmaz.
 */
@Service
public class EventAdmissionService implements EventAdmissionHooks {

    static final int MAX_QUESTIONS = 3;
    static final int MAX_QUESTION_LEN = 200;
    static final int MAX_ANSWER_LEN = 500;
    static final int MAX_NOTE_LEN = 500;
    static final int NOTIFY_LIMIT = 500;
    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final EnumSet<UserEvent.Status> OPEN_STATUSES =
            EnumSet.of(UserEvent.Status.ACTIVE, UserEvent.Status.PENDING_REVIEW);

    private final EventService events;
    private final EventAdmissionRepository configs;
    private final EventApplicationRepository apps;
    private final AdmissionEventRepository eventRows;
    private final UserEventRepository eventRepo;
    private final EventRsvpRepository rsvps;
    private final NotificationService notifications;
    private final BlockService blocks;
    private final CommunityService communities;
    private final AdmissionSettings settings;

    public EventAdmissionService(EventService events, EventAdmissionRepository configs, EventApplicationRepository apps,
                                 AdmissionEventRepository eventRows, UserEventRepository eventRepo,
                                 EventRsvpRepository rsvps, NotificationService notifications, BlockService blocks,
                                 CommunityService communities, AdmissionSettings settings) {
        this.events = events;
        this.configs = configs;
        this.apps = apps;
        this.eventRows = eventRows;
        this.eventRepo = eventRepo;
        this.rsvps = rsvps;
        this.notifications = notifications;
        this.blocks = blocks;
        this.communities = communities;
        this.settings = settings;
    }

    /** T25: etkinlik sohbet odasi senkronu (setter + @Lazy; null iken no-op). */
    private EventChatHooks chat;

    @org.springframework.beans.factory.annotation.Autowired
    public void setChat(@org.springframework.context.annotation.Lazy EventChatHooks chat) {
        this.chat = chat;
    }

    // ---- yapilandirma ----

    @Transactional(readOnly = true)
    public ConfigView config(Actor a, Long eventId) {
        UserEvent e = events.loadVisible(a, eventId);
        EventAdmission c = configs.findById(e.getId()).orElse(null);
        return new ConfigView(e.getId(), c == null ? Mode.OPEN : c.getMode(), c == null ? List.of() : c.questions());
    }

    /** Organizator alim modunu ve (APPROVAL ise) en fazla 3 soruyu belirler. */
    @Transactional
    public ConfigView setConfig(Actor a, Long eventId, ConfigRequest r) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        if (e.getStatus() != UserEvent.Status.ACTIVE && e.getStatus() != UserEvent.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_EDITABLE", "Bu etkinlik düzenlenemez.");
        }
        if (!e.getEndsAt().isAfter(Instant.now())) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_ENDED", "Sona ermiş etkinlik düzenlenemez.");
        }
        List<String> questions = cleanQuestions(r.questions());
        eventRows.lock(eventId);
        EventAdmission c = configs.findById(eventId).orElseGet(() -> new EventAdmission(eventId));
        Mode old = c.getMode();
        c.setMode(r.mode());
        c.setQuestions(r.mode() == Mode.APPROVAL ? questions : List.of());
        c.setUpdatedAt(Instant.now());
        configs.save(c);
        if (old == Mode.APPROVAL && r.mode() == Mode.OPEN) {
            // Etkinlik herkese acildi: bekleyen basvurular anlamini yitirir; kabul edilenler GOING olarak kalir.
            List<Status> open = List.of(Status.PENDING, Status.WAITLISTED);
            List<Long> users = apps.userIdsByStatus(eventId, open);
            apps.closeAll(eventId, open, Status.CANCELLED, Instant.now());
            for (Long uid : users.stream().limit(NOTIFY_LIMIT).toList()) {
                notifications.sendTemplated(uid, NotificationType.EVENT, "notif.admission.modeOpen", data(eventId, null),
                        e.getTitle());
            }
        }
        return new ConfigView(eventId, c.getMode(), c.questions());
    }

    // ---- basvuru (kullanici) ----

    @Transactional
    public ApplicationView apply(Actor a, Long eventId, ApplyRequest r) {
        UserEvent e = events.loadVisible(a, eventId);
        requireOpenForAdmission(e);
        if (e.isRegistrationClosed()) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_REGISTRATION_CLOSED", "Bu etkinliğin kayıtları kapatıldı.");
        }
        EventAdmission c = configs.findById(eventId).orElse(null);
        if (c == null || c.getMode() != Mode.APPROVAL) {
            throw new ApiException(HttpStatus.CONFLICT, "ADMISSION_NOT_REQUIRED",
                    "Bu etkinliğe başvuru gerekmez, doğrudan katılabilirsiniz.");
        }
        if (e.getCreatedBy().equals(a.id())) {
            throw new ApiException(HttpStatus.CONFLICT, "ORGANIZER_CANNOT_APPLY", "Kendi etkinliğinize başvuramazsınız.");
        }
        // Engel iliskisi varsa etkinligin varligi sizdirilmaz.
        if (blocks.isBlocked(e.getCreatedBy(), a.id())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND", "Etkinlik bulunamadı.");
        }
        String note = r == null ? null : Texts.blankToNull(r.note());
        List<String> answers = cleanAnswers(r == null ? null : r.answers(), c.questions());

        eventRows.lock(eventId);
        EventApplication app = apps.findByEventIdAndUserId(eventId, a.id()).orElse(null);
        if (app != null) {
            switch (app.getStatus()) {
                case REJECTED -> throw new ApiException(HttpStatus.CONFLICT, "APPLICATION_REJECTED",
                        "Başvurunuz organizatör tarafından reddedildi.");
                case CANCELLED -> { /* yeniden basvuru: satir sifirlanir */ }
                default -> throw new ApiException(HttpStatus.CONFLICT, "ALREADY_APPLIED", "Bu etkinliğe zaten başvurdunuz.");
            }
        } else if (rsvps.findByEventIdAndUserId(eventId, a.id())
                .map(x -> x.getStatus() == EventRsvp.Status.GOING).orElse(false)) {
            // Mod APPROVAL'a cevrilmeden once katilmis kullanici
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_APPLIED", "Bu etkinliğe zaten başvurdunuz.");
        }
        if (app == null) {
            app = new EventApplication(eventId, a.id());
        }
        app.setStatus(Status.PENDING);
        app.setNote(note);
        app.setAnswers(answers);
        app.setQueuedAt(null);
        app.setDecidedBy(null);
        app.setDecidedAt(null);
        app.setDecisionNote(null);
        app.setUpdatedAt(Instant.now());
        apps.saveAndFlush(app);

        User u = communities.usersById(List.of(a.id())).get(a.id());
        notifications.sendTemplated(e.getCreatedBy(), NotificationType.EVENT, "notif.admission.received",
                data(eventId, app.getId()), e.getTitle(), u == null ? "-" : u.getDisplayName());
        return view(app, e.getTitle());
    }

    @Transactional(readOnly = true)
    public ApplicationView mine(Actor a, Long eventId) {
        UserEvent e = events.load(eventId);
        EventApplication app = apps.findByEventIdAndUserId(eventId, a.id()).orElseThrow(EventAdmissionService::appNotFound);
        return view(app, e.getTitle());
    }

    @Transactional(readOnly = true)
    public CursorPage<ApplicationView> myApplications(Actor a, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<EventApplication> rows = apps.mine(a.id(), Paging.descStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, EventApplication::getId, items -> {
            Map<Long, String> titles = new java.util.HashMap<>();
            eventRepo.findAllById(items.stream().map(EventApplication::getEventId).distinct().toList())
                    .forEach(ev -> titles.put(ev.getId(), ev.getTitle()));
            return items.stream().map(x -> view(x, titles.get(x.getEventId()))).toList();
        });
    }

    /** Basvuruyu geri cek / katilimdan vazgec. ACCEPTED ise koltuk serbest kalir ve siradaki terfi eder. */
    @Transactional
    public ApplicationView withdraw(Actor a, Long eventId) {
        UserEvent e = events.load(eventId);
        eventRows.lock(eventId);
        EventApplication app = apps.findByEventIdAndUserId(eventId, a.id()).orElseThrow(EventAdmissionService::appNotFound);
        switch (app.getStatus()) {
            case CANCELLED -> { return view(app, e.getTitle()); }
            case REJECTED -> throw new ApiException(HttpStatus.CONFLICT, "INVALID_APPLICATION_STATE",
                    "Başvurunun durumu bu işleme uygun değil.");
            case ACCEPTED -> {
                releaseSeat(e, a.id());
                setStatus(app, Status.CANCELLED, null, null);
                apps.saveAndFlush(app);
                promoteWaitlist(e);
            }
            default -> {
                setStatus(app, Status.CANCELLED, null, null);
                apps.saveAndFlush(app);
            }
        }
        return view(app, e.getTitle());
    }

    // ---- organizator ----

    @Transactional(readOnly = true)
    public CursorPage<ApplicantView> list(Actor a, Long eventId, Status status, Long cursor, int size) {
        events.requireManager(a, events.load(eventId));
        int s = CursorPage.clampSize(size);
        PageRequest page = PageRequest.of(0, s + 1);
        List<EventApplication> rows = status == null
                ? apps.page(eventId, Paging.ascStart(cursor), page)
                : apps.pageByStatus(eventId, status, Paging.ascStart(cursor), page);
        Set<Long> hideAvatar = blocks.hiddenFrom(a.id()); // engel iliskisi olanin avatari gorunmez
        return Paging.map(rows, s, EventApplication::getId, items -> {
            Map<Long, User> users = communities.usersById(items.stream().map(EventApplication::getUserId).toList());
            return items.stream().map(x -> {
                User u = users.get(x.getUserId());
                return new ApplicantView(x.getId(), x.getUserId(), u == null ? "Kullanıcı" : u.getDisplayName(),
                        u == null || hideAvatar.contains(x.getUserId()) ? null : u.getAvatarUrl(),
                        u == null ? null : u.getDepartment(), x.getStatus(),
                        x.getNote(), x.answers(), x.getQueuedAt(), x.getCreatedAt(), x.getUpdatedAt());
            }).toList();
        });
    }

    @Transactional(readOnly = true)
    public AdmissionSummary summary(Actor a, Long eventId) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        Mode mode = configs.findById(eventId).map(EventAdmission::getMode).orElse(Mode.OPEN);
        return new AdmissionSummary(eventId, mode, e.getCapacity(), eventRepo.goingCount(eventId),
                apps.countByEventIdAndStatus(eventId, Status.PENDING), apps.countByEventIdAndStatus(eventId, Status.ACCEPTED),
                apps.countByEventIdAndStatus(eventId, Status.WAITLISTED), apps.countByEventIdAndStatus(eventId, Status.REJECTED),
                apps.countByEventIdAndStatus(eventId, Status.CANCELLED));
    }

    /** Toplu karar: her kimlik bagimsiz sonuclanir (hatali olan digerlerini engellemez). */
    @Transactional
    public DecisionResult decide(Actor a, Long eventId, List<Long> ids, Action action, String reason) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        requireOpenForAdmission(e);
        eventRows.lock(eventId);
        String note = Texts.blankToNull(reason);
        List<DecisionItem> out = new ArrayList<>();
        for (Long id : new LinkedHashSet<>(ids)) {
            EventApplication app = id == null ? null : apps.findByIdAndEventId(id, eventId).orElse(null);
            if (app == null) {
                out.add(new DecisionItem(id, null, "APPLICATION_NOT_FOUND"));
                continue;
            }
            try {
                out.add(new DecisionItem(id, applyDecision(e, app, action, note, a), null));
            } catch (ApiException ex) {
                out.add(new DecisionItem(id, app.getStatus(), ex.code()));
            }
        }
        return new DecisionResult(out);
    }

    /** Tek karar; gecersiz gecis hata olarak doner. */
    @Transactional
    public DecisionItem decideOne(Actor a, Long eventId, Long appId, Action action, String reason) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        requireOpenForAdmission(e);
        eventRows.lock(eventId);
        EventApplication app = apps.findByIdAndEventId(appId, eventId).orElseThrow(EventAdmissionService::appNotFound);
        return new DecisionItem(appId, applyDecision(e, app, action, Texts.blankToNull(reason), a), null);
    }

    /** Organizator katilimciyi cikarir (basvurusu REJECTED olur); yer acilirsa siradaki terfi eder. */
    @Transactional
    public void removeParticipant(Actor a, Long eventId, Long userId) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        eventRows.lock(eventId);
        EventApplication app = apps.findByEventIdAndUserId(eventId, userId).orElse(null);
        if (app != null && app.getStatus() == Status.ACCEPTED) {
            applyDecision(e, app, Action.REJECT, null, a);
            return;
        }
        // APPROVAL oncesi katilmis (basvurusuz) ya da OPEN mod katilimcisi
        EventRsvp going = rsvps.findByEventIdAndUserId(eventId, userId)
                .filter(x -> x.getStatus() == EventRsvp.Status.GOING).orElse(null);
        if (going == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "PARTICIPANT_NOT_FOUND", "Katılımcı bulunamadı.");
        }
        releaseSeat(e, userId);
        notifications.sendTemplated(userId, NotificationType.EVENT, "notif.admission.removed", data(eventId, null), e.getTitle());
        promoteWaitlist(e);
    }

    // ---- EventAdmissionHooks ----

    @Override
    public boolean requireApproval() {
        return settings.requireApproval();
    }

    @Override
    public void beforeCreate(Actor a) {
        if (a.admin()) {
            return;
        }
        int max = settings.maxOpenPerUser();
        if (max > 0 && eventRows.countOpen(a.id(), OPEN_STATUSES, Instant.now()) >= max) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_LIMIT_OPEN",
                    "Aynı anda en fazla " + max + " açık etkinliğiniz olabilir.", String.valueOf(max));
        }
        int daily = settings.dailyCreateLimit();
        if (daily > 0) {
            Instant since = LocalDate.now(ZONE).atStartOfDay(ZONE).toInstant();
            if (eventRows.countCreatedSince(a.id(), since) >= daily) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "EVENT_LIMIT_DAILY",
                        "Günlük etkinlik açma sınırına (" + daily + ") ulaştınız.", String.valueOf(daily));
            }
        }
    }

    @Override
    public void guardDirectRsvp(UserEvent e, EventRsvp.Status status) {
        if (status == EventRsvp.Status.GOING && modeOf(e.getId()) == Mode.APPROVAL) {
            throw new ApiException(HttpStatus.CONFLICT, "APPLICATION_REQUIRED",
                    "Bu etkinliğe katılmak için başvuru yapmalısınız.");
        }
    }

    @Override
    @Transactional
    public boolean withdrawAccepted(Actor a, UserEvent e) {
        boolean accepted = apps.findByEventIdAndUserId(e.getId(), a.id())
                .map(x -> x.getStatus() == Status.ACCEPTED).orElse(false);
        if (!accepted) {
            return false;
        }
        withdraw(a, e.getId());
        return true;
    }

    @Override
    @Transactional
    public void afterCapacityChanged(UserEvent e) {
        if (apps.countByEventIdAndStatus(e.getId(), Status.WAITLISTED) == 0) {
            return;
        }
        eventRows.lock(e.getId());
        promoteWaitlist(e);
        // Cagiran (EventService.update) ayni nesneyi yanitta gosterir: guncel sayi.
        e.setGoingCount(eventRepo.goingCount(e.getId()));
    }

    @Override
    @Transactional
    public void onEventCancelled(UserEvent e) {
        List<Status> open = List.of(Status.PENDING, Status.WAITLISTED);
        List<Long> users = apps.userIdsByStatus(e.getId(), open);
        if (users.isEmpty()) {
            return;
        }
        apps.closeAll(e.getId(), open, Status.CANCELLED, Instant.now());
        for (Long uid : users.stream().limit(NOTIFY_LIMIT).toList()) {
            notifications.sendTemplated(uid, NotificationType.EVENT, "notif.event.cancelled", data(e.getId(), null), e.getTitle());
        }
    }

    @Override
    public void requireEligibleForMark(UserEvent e, Long userId) {
        if (modeOf(e.getId()) != Mode.APPROVAL) {
            return;
        }
        boolean going = rsvps.findByEventIdAndUserId(e.getId(), userId)
                .map(x -> x.getStatus() == EventRsvp.Status.GOING).orElse(false);
        if (!going) {
            throw new ApiException(HttpStatus.CONFLICT, "NOT_ACCEPTED", "Bu kullanıcı etkinliğe kabul edilmemiş.");
        }
    }

    // ---- durum makinesi ----

    /** Etkinlik satiri kilitliyken cagrilir. Yeni durumu doner; gecersiz gecis ApiException. */
    Status applyDecision(UserEvent e, EventApplication app, Action action, String reason, Actor decider) {
        Status cur = app.getStatus();
        switch (action) {
            case ACCEPT -> {
                if (cur == Status.ACCEPTED) {
                    return cur;
                }
                requireIn(cur, Status.PENDING, Status.WAITLISTED);
                requireUsable(e, app.getUserId());
                if (takeSeat(e.getId(), app.getUserId())) {
                    setStatus(app, Status.ACCEPTED, decider.id(), null);
                    notifyApp(e, app, "notif.admission.accepted");
                } else if (cur == Status.PENDING) {
                    // Kontenjan dolu: otomatik bekleme listesi
                    app.setQueuedAt(Instant.now());
                    setStatus(app, Status.WAITLISTED, decider.id(), null);
                    notifyApp(e, app, "notif.admission.waitlisted");
                }
            }
            case WAITLIST -> {
                if (cur == Status.WAITLISTED) {
                    return cur;
                }
                requireIn(cur, Status.PENDING);
                app.setQueuedAt(Instant.now());
                setStatus(app, Status.WAITLISTED, decider.id(), null);
                notifyApp(e, app, "notif.admission.waitlisted");
            }
            case REJECT -> {
                if (cur == Status.REJECTED) {
                    return cur;
                }
                requireIn(cur, Status.PENDING, Status.WAITLISTED, Status.ACCEPTED);
                boolean removed = cur == Status.ACCEPTED;
                if (removed) {
                    releaseSeat(e, app.getUserId());
                }
                setStatus(app, Status.REJECTED, decider.id(), reason);
                if (removed) {
                    notifyApp(e, app, "notif.admission.removed");
                } else if (reason == null) {
                    notifyApp(e, app, "notif.admission.rejected");
                } else {
                    notifications.sendTemplated(app.getUserId(), NotificationType.EVENT, "notif.admission.rejectedNote",
                            data(e.getId(), app.getId()), e.getTitle(), reason);
                }
            }
        }
        apps.saveAndFlush(app);
        if (cur == Status.ACCEPTED && app.getStatus() == Status.REJECTED) {
            promoteWaitlist(e);
        }
        return app.getStatus();
    }

    /**
     * Yer varsa bekleme listesinin basindan sirayla terfi ettirir (kilit tutulurken cagrilir). Kullanilamaz
     * (silinmis/askida/engelli) adaylar CANCELLED yapilip atlanir.
     */
    void promoteWaitlist(UserEvent e) {
        if (e.getStatus() != UserEvent.Status.ACTIVE || !e.getEndsAt().isAfter(Instant.now())) {
            return;
        }
        while (true) {
            Integer cap = eventRows.capacityOf(e.getId());
            if (cap != null && eventRepo.goingCount(e.getId()) >= cap) {
                return;
            }
            List<EventApplication> next = apps.waitlist(e.getId(), Status.WAITLISTED, PageRequest.of(0, 1));
            if (next.isEmpty()) {
                return;
            }
            EventApplication w = next.get(0);
            if (!usable(e, w.getUserId())) {
                setStatus(w, Status.CANCELLED, null, null);
                apps.saveAndFlush(w);
                continue;
            }
            if (!takeSeat(e.getId(), w.getUserId())) {
                return;
            }
            setStatus(w, Status.ACCEPTED, null, null);
            apps.saveAndFlush(w);
            notifyApp(e, w, "notif.admission.promoted");
        }
    }

    // ---- ic yardimcilar ----

    /** Atomik koltuk rezervasyonu + GOING RSVP (varsa INTERESTED'dan yukseltilir). Yer yoksa false. */
    private boolean takeSeat(Long eventId, Long userId) {
        if (eventRepo.tryIncrementGoing(eventId) == 0) {
            return false;
        }
        EventRsvp r = rsvps.findByEventIdAndUserId(eventId, userId).orElse(null);
        if (r == null) {
            rsvps.save(new EventRsvp(eventId, userId, EventRsvp.Status.GOING));
        } else {
            r.setStatus(EventRsvp.Status.GOING);
            r.setRemindedDay(false);
            r.setRemindedHour(false);
            rsvps.save(r);
        }
        if (chat != null) {
            chat.onGoing(eventId, userId);
        }
        return true;
    }

    /** GOING RSVP'yi siler ve koltugu birakir (yalnizca GOING ise sayac duser). */
    private void releaseSeat(UserEvent e, Long userId) {
        rsvps.findByEventIdAndUserId(e.getId(), userId).ifPresent(r -> {
            if (r.getStatus() == EventRsvp.Status.GOING) {
                eventRepo.decrementGoing(e.getId());
                if (chat != null) {
                    chat.onLeft(e.getId(), userId);
                }
            }
            rsvps.delete(r);
        });
    }

    private boolean usable(UserEvent e, Long userId) {
        User u = communities.usersById(List.of(userId)).get(userId);
        return u != null && u.getStatus() == UserStatus.ACTIVE && !blocks.isBlocked(e.getCreatedBy(), userId);
    }

    private void requireUsable(UserEvent e, Long userId) {
        if (!usable(e, userId)) {
            throw new ApiException(HttpStatus.CONFLICT, "APPLICANT_UNAVAILABLE", "Başvuran kullanıcı artık kullanılamıyor.");
        }
    }

    private static void requireIn(Status cur, Status... allowed) {
        for (Status s : allowed) {
            if (cur == s) {
                return;
            }
        }
        throw new ApiException(HttpStatus.CONFLICT, "INVALID_APPLICATION_STATE", "Başvurunun durumu bu işleme uygun değil.");
    }

    private static void setStatus(EventApplication app, Status s, Long decidedBy, String note) {
        Instant now = Instant.now();
        app.setStatus(s);
        app.setUpdatedAt(now);
        if (decidedBy != null) {
            app.setDecidedBy(decidedBy);
            app.setDecidedAt(now);
            app.setDecisionNote(note);
        }
    }

    private void requireOpenForAdmission(UserEvent e) {
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_OPEN", "Etkinlik henüz yayında değil.");
        }
        if (!e.getEndsAt().isAfter(Instant.now())) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_ENDED", "Etkinlik sona erdi.");
        }
    }

    private Mode modeOf(Long eventId) {
        return configs.findById(eventId).map(EventAdmission::getMode).orElse(Mode.OPEN);
    }

    private void notifyApp(UserEvent e, EventApplication app, String key) {
        notifications.sendTemplated(app.getUserId(), NotificationType.EVENT, key, data(e.getId(), app.getId()), e.getTitle());
    }

    private static Map<String, String> data(Long eventId, Long appId) {
        return appId == null ? Map.of("eventId", eventId.toString())
                : Map.of("eventId", eventId.toString(), "applicationId", appId.toString());
    }

    private static ApiException appNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "APPLICATION_NOT_FOUND", "Başvuru bulunamadı.");
    }

    private ApplicationView view(EventApplication x, String title) {
        Integer pos = null;
        if (x.getStatus() == Status.WAITLISTED && x.getQueuedAt() != null) {
            pos = (int) apps.waitlistAhead(x.getEventId(), Status.WAITLISTED, x.getQueuedAt(), x.getId()) + 1;
        }
        return new ApplicationView(x.getId(), x.getEventId(), title, x.getStatus(), x.getNote(), x.answers(), pos,
                x.getDecisionNote(), x.getCreatedAt(), x.getUpdatedAt());
    }

    static List<String> cleanQuestions(List<String> raw) {
        List<String> out = new ArrayList<>();
        if (raw != null) {
            for (String q : raw) {
                String t = q == null ? "" : q.trim();
                if (t.isEmpty()) {
                    continue;
                }
                if (t.length() > MAX_QUESTION_LEN) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Soru en fazla 200 karakter olabilir.");
                }
                out.add(t);
            }
        }
        if (out.size() > MAX_QUESTIONS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "En fazla 3 soru tanımlanabilir.");
        }
        return out;
    }

    /** Her tanimli soru icin bos olmayan bir yanit gerekir; fazla yanit reddedilir. */
    static List<String> cleanAnswers(List<String> raw, List<String> questions) {
        List<String> given = raw == null ? List.of() : raw;
        if (given.size() > questions.size()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Yanıt sayısı soru sayısını aşamaz.");
        }
        List<String> out = new ArrayList<>();
        for (int i = 0; i < questions.size(); i++) {
            String t = i < given.size() && given.get(i) != null ? given.get(i).trim() : "";
            if (t.isEmpty()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWERS_REQUIRED", "Tüm sorulara yanıt vermelisiniz.");
            }
            if (t.length() > MAX_ANSWER_LEN) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Yanıt en fazla 500 karakter olabilir.");
            }
            out.add(t);
        }
        return out;
    }

    /** Test/denetim: mod. */
    Optional<EventAdmission> configOf(Long eventId) {
        return configs.findById(eventId);
    }
}
