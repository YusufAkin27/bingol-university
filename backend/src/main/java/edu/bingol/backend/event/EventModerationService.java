package edu.bingol.backend.event;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.event.admission.EventAdmission;
import edu.bingol.backend.event.admission.EventApplication;
import edu.bingol.backend.event.admission.EventApplicationRepository;
import edu.bingol.backend.event.dto.EventAdminDtos.AdminEventDetail;
import edu.bingol.backend.event.dto.EventAdminDtos.ModerationEntry;
import edu.bingol.backend.event.dto.EventAdminDtos.RequestCounts;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici etkinlik moderasyonu: suzmeli liste, detay ve durum gecisleri. Durum makinesi (UserEvent.Status):
 * <pre>
 * PENDING_REVIEW -> ACTIVE (approve) | REJECTED (reject) | CANCELLED (cancel)      [approve/reject: EventService.review]
 * ACTIVE         -> HIDDEN (hide)    | CANCELLED (cancel)
 * HIDDEN         -> ACTIVE (unhide)  | CANCELLED (cancel)
 * REJECTED, CANCELLED: son durum (409 EVENT_INVALID_TRANSITION)
 * </pre>
 * Her gecis event_moderation_log'a yazilir (sebep zorunlu). Gizleme sessizdir (katilimcilara bildirim yok);
 * iptalde katilimcilar/istek sahipleri ve etkinlik sahibi (sebepli) haberdar edilir.
 */
@Service
public class EventModerationService {

    static final int MAX_Q = 100;

    private final UserEventRepository events;
    private final EventModerationLogRepository log;
    private final EventService eventService;
    private final EventAttendanceRepository attendance;
    private final EventApplicationRepository applications;
    private final CommunityService communities;
    private final NotificationService notifications;

    public EventModerationService(UserEventRepository events, EventModerationLogRepository log,
                                  EventService eventService, EventAttendanceRepository attendance,
                                  EventApplicationRepository applications, CommunityService communities,
                                  NotificationService notifications) {
        this.events = events;
        this.log = log;
        this.eventService = eventService;
        this.attendance = attendance;
        this.applications = applications;
        this.communities = communities;
        this.notifications = notifications;
    }

    // ---- liste ----

    /**
     * @param status PENDING_REVIEW|ACTIVE|REJECTED|CANCELLED|HIDDEN ya da ALL; bos = PENDING_REVIEW (eski davranis)
     * @param joinPolicy OPEN | APPROVAL | null
     * @param from baslangic zamani araligi [from, to)
     */
    @Transactional(readOnly = true)
    public CursorPage<EventView> list(String status, String q, Long communityId, boolean standalone,
                                      EventAdmission.Mode joinPolicy, Instant from, Instant to,
                                      Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        boolean any = false;
        UserEvent.Status st = UserEvent.Status.PENDING_REVIEW;
        if (status != null && !status.isBlank()) {
            String up = status.trim().toUpperCase(Locale.ROOT);
            if (up.equals("ALL")) {
                any = true;
            } else {
                try {
                    st = UserEvent.Status.valueOf(up);
                } catch (IllegalArgumentException ex) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
                }
            }
        }
        Instant f = from == null ? EventService.MIN_DATE : from;
        Instant t = to == null ? EventService.FAR_FUTURE : to;
        if (!t.isAfter(f)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Tarih aralığı geçersiz.");
        }
        String like = likePattern(q);
        int policy = joinPolicy == null ? 0 : joinPolicy == EventAdmission.Mode.OPEN ? 1 : 2;
        List<UserEvent> rows = events.adminSearch(any, st, communityId == null ? 0L : communityId, standalone, f, t,
                policy, like != null, like == null ? "" : like, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, UserEvent::getId, items -> eventService.adminViews(items, false));
    }

    /** Turkce katlama (I/i/ı/İ -> i, kucuk harf), LIKE ozel karakterleri '!' ile kacirilir; bos ise null. */
    static String likePattern(String q) {
        if (q == null || q.isBlank()) {
            return null;
        }
        String t = q.trim();
        if (t.length() > MAX_Q) {
            t = t.substring(0, MAX_Q);
        }
        t = fold(t).replace("!", "!!").replace("%", "!%").replace("_", "!_");
        return "%" + t + "%";
    }

    static String fold(String s) {
        return s.replace('İ', 'i').replace('I', 'i').replace('ı', 'i').toLowerCase(Locale.ROOT);
    }

    // ---- detay ----

    @Transactional(readOnly = true)
    public AdminEventDetail detail(Long id) {
        UserEvent e = eventService.load(id);
        EventView view = eventService.adminViews(List.of(e), true).get(0);
        User organizer = communities.usersById(List.of(e.getCreatedBy())).get(e.getCreatedBy());
        List<EventModerationLog> rows = log.recent(id, PageRequest.of(0, 20));
        Map<Long, User> admins = communities.usersById(rows.stream().map(EventModerationLog::getAdminId)
                .filter(x -> x != null).distinct().toList());
        List<ModerationEntry> history = rows.stream().map(l -> new ModerationEntry(l.getId(), l.getAdminId(),
                l.getAdminId() == null || admins.get(l.getAdminId()) == null ? null
                        : admins.get(l.getAdminId()).getDisplayName(),
                l.getAction(), UserEvent.Status.valueOf(l.getFromStatus()), UserEvent.Status.valueOf(l.getToStatus()),
                l.getReason(), l.getCreatedAt())).toList();
        long attended = attendance.findByEventId(id).stream().filter(EventAttendance::isPresent).count();
        RequestCounts counts = new RequestCounts(
                applications.countByEventIdAndStatus(id, EventApplication.Status.PENDING),
                applications.countByEventIdAndStatus(id, EventApplication.Status.WAITLISTED),
                applications.countByEventIdAndStatus(id, EventApplication.Status.ACCEPTED),
                applications.countByEventIdAndStatus(id, EventApplication.Status.REJECTED),
                applications.countByEventIdAndStatus(id, EventApplication.Status.CANCELLED));
        return new AdminEventDetail(view, organizer == null ? null : organizer.getEmail(), counts, attended,
                e.getReviewNote(), e.getModerationReason(), e.getModeratedBy(), e.getModeratedAt(), history,
                allowedActions(e.getStatus()));
    }

    static List<String> allowedActions(UserEvent.Status s) {
        return switch (s) {
            case PENDING_REVIEW -> List.of("approve", "reject", "edit", "cancel", "delete");
            case ACTIVE -> List.of("edit", "hide", "cancel", "delete");
            case HIDDEN -> List.of("unhide", "cancel", "delete");
            case REJECTED, CANCELLED -> List.of();
        };
    }

    // ---- gecisler ----

    /** ACTIVE -> HIDDEN. Sessiz (bildirim yok); listelerden/aramadan/akistan duser, dogrudan erisimde 404. */
    @Transactional
    public AdminEventDetail hide(Long adminId, Long id, String reason) {
        UserEvent e = eventService.load(id);
        requireStatus(e, "hide", UserEvent.Status.ACTIVE);
        move(e, "HIDE", UserEvent.Status.HIDDEN, adminId, reason);
        return detail(id);
    }

    /** HIDDEN -> ACTIVE. */
    @Transactional
    public AdminEventDetail unhide(Long adminId, Long id, String reason) {
        UserEvent e = eventService.load(id);
        requireStatus(e, "unhide", UserEvent.Status.HIDDEN);
        move(e, "UNHIDE", UserEvent.Status.ACTIVE, adminId, reason);
        return detail(id);
    }

    /**
     * ACTIVE | PENDING_REVIEW | HIDDEN -> CANCELLED. Katilimcilara/istek sahiplerine iptal bildirimi, sohbet odasi
     * kapanir, hatirlatmalar durur; etkinlik sahibine sebepli bildirim gider.
     */
    @Transactional
    public AdminEventDetail cancel(Long adminId, Long id, String reason) {
        return cancelOrDelete(adminId, id, reason, "CANCEL");
    }

    /**
     * Yonetici silme (DELETE /api/admin/events/{id}). Yumusak silme: etkinlik CANCELLED olur, satir fiziksel silinmez
     * (RSVP, yoklama, sertifika, KVKK disa aktarimi ve denetim gecmisi buna baglidir). Yan etkiler iptalle aynidir;
     * gecmise DELETE olarak yazilir. Kullanici tarafinda CANCELLED etkinlik herkese 404'tur (organizator haric).
     */
    @Transactional
    public AdminEventDetail delete(Long adminId, Long id, String reason) {
        return cancelOrDelete(adminId, id, reason, "DELETE");
    }

    /**
     * Yonetici duzenlemesi (PATCH). Kurallar EventService.update ile ayni (ACTIVE/PENDING_REVIEW, bitmemis; kapasite
     * katilimcidan az olamaz; degisen saat/yer katilimcilara bildirilir). reason istege bagli; gecmise EDIT yazilir.
     */
    @Transactional
    public AdminEventDetail edit(Long adminId, Long id, UpdateEventRequest r, String reason) {
        UserEvent before = eventService.load(id);
        UserEvent.Status st = before.getStatus();
        eventService.update(new Actor(adminId == null ? -1L : adminId, true), id, r);
        EventModerationLog l = new EventModerationLog();
        l.setEventId(id);
        l.setAdminId(adminId);
        l.setAction("EDIT");
        l.setFromStatus(st.name());
        l.setToStatus(st.name());
        String rs = Texts.blankToNull(reason);
        l.setReason(rs == null ? null : rs.length() > 300 ? rs.substring(0, 300) : rs);
        log.save(l);
        return detail(id);
    }

    private AdminEventDetail cancelOrDelete(Long adminId, Long id, String reason, String action) {
        UserEvent e = eventService.load(id);
        requireStatus(e, action.toLowerCase(Locale.ROOT), UserEvent.Status.ACTIVE, UserEvent.Status.PENDING_REVIEW, UserEvent.Status.HIDDEN);
        UserEvent.Status from = e.getStatus();
        String clean = clean(reason);
        eventService.cancelByModerator(e); // durumu CANCELLED yapar, kapagi birakir, bildirir, odayi kapatir
        e.setModerationReason(clean);
        e.setModeratedBy(adminId);
        e.setModeratedAt(Instant.now());
        events.saveAndFlush(e);
        record(e.getId(), adminId, action, from, UserEvent.Status.CANCELLED, clean);
        notifications.sendTemplated(e.getCreatedBy(), NotificationType.EVENT, "notif.event.cancelledByAdmin",
                Map.of("eventId", id.toString()), e.getTitle(), clean);
        return detail(id);
    }

    /** Rapor cozumleme: HIDE/UNHIDE'in rapor kolu (yalnizca ACTIVE <-> HIDDEN; digerleri sessizce yok sayilir). */
    @Transactional
    public void hideForReport(Long eventId, boolean hide) {
        events.findById(eventId).ifPresent(e -> {
            UserEvent.Status want = hide ? UserEvent.Status.HIDDEN : UserEvent.Status.ACTIVE;
            UserEvent.Status need = hide ? UserEvent.Status.ACTIVE : UserEvent.Status.HIDDEN;
            if (e.getStatus() == need) {
                move(e, hide ? "REPORT_HIDE" : "REPORT_UNHIDE", want, null, hide ? "report" : "report-restored");
            }
        });
    }

    private void move(UserEvent e, String action, UserEvent.Status to, Long adminId, String reason) {
        UserEvent.Status from = e.getStatus();
        String clean = clean(reason);
        e.setStatus(to);
        e.setModerationReason(clean);
        e.setModeratedBy(adminId);
        e.setModeratedAt(Instant.now());
        e.setUpdatedAt(Instant.now());
        events.saveAndFlush(e);
        record(e.getId(), adminId, action, from, to, clean);
    }

    private void record(Long eventId, Long adminId, String action, UserEvent.Status from, UserEvent.Status to,
                        String reason) {
        EventModerationLog l = new EventModerationLog();
        l.setEventId(eventId);
        l.setAdminId(adminId);
        l.setAction(action);
        l.setFromStatus(from.name());
        l.setToStatus(to.name());
        l.setReason(reason);
        log.save(l);
    }

    private static String clean(String reason) {
        String r = Texts.blankToNull(reason);
        if (r == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        return r.length() > 300 ? r.substring(0, 300) : r;
    }

    private static void requireStatus(UserEvent e, String action, UserEvent.Status... allowed) {
        for (UserEvent.Status s : allowed) {
            if (e.getStatus() == s) {
                return;
            }
        }
        throw new ApiException(HttpStatus.CONFLICT, "EVENT_INVALID_TRANSITION",
                "Etkinliğin mevcut durumunda bu işlem yapılamaz.", e.getStatus().name(), action);
    }
}
