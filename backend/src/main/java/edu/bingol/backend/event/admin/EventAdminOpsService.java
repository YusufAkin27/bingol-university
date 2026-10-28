package edu.bingol.backend.event.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.event.AttendanceService;
import edu.bingol.backend.event.EventAttendance;
import edu.bingol.backend.event.EventAttendanceRepository;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAnnouncementRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminApplicationPage;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminApplicationRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAttendanceRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAttendanceView;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminCertificateRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminFeedbackPage;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminFeedbackRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminOrganizerRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.ApplicationDecision;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.ApplicationSummary;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AttendanceMarkResult;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AttendanceSummary;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.FeedbackStats;
import edu.bingol.backend.event.admission.AdmissionDtos.DecisionItem;
import edu.bingol.backend.event.admission.EventAdmission;
import edu.bingol.backend.event.admission.EventAdmissionService;
import edu.bingol.backend.event.admission.EventApplication;
import edu.bingol.backend.event.admission.EventApplicationRepository;
import edu.bingol.backend.event.extras.CoOrganizer;
import edu.bingol.backend.event.extras.CoOrganizerRepository;
import edu.bingol.backend.event.extras.EventAnnouncement;
import edu.bingol.backend.event.extras.EventCertificate;
import edu.bingol.backend.event.extras.EventFeedback;
import edu.bingol.backend.event.extras.EventFeedbackRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici etkinlik derin yonetimi (P07): basvuru, yoklama, sertifika, geri bildirim, duyuru ve duzenleyen islemleri.
 * Is kurallari mevcut servislerden yeniden kullanilir (kapasite: EventAdmissionService atomik koltuk mantigi; yoklama:
 * AttendanceService; sertifika dogrulamasi: CertificateService). Bu sinif yalnizca yonetici gorunumunu (maskeli e-posta,
 * anonim geri bildirim) ve yonetici-ozel kurallari (son duzenleyen korumasi, sertifika iptali) ekler.
 *
 * <p>Kullanici kaydi gerektiren yazmalar (basvuru karari, yoklama isaretleme) icin yonetici JWT ile girmis olmalidir:
 * event_application.decided_by / event_attendance.marked_by app_user'a FK'dir; Basic auth yoneticisinin kaydi yoktur.
 */
@Service
public class EventAdminOpsService {

    static final int MAX_PAGE = 100;
    static final int MAX_ATTENDANCE_ROWS = 5000;
    static final int MAX_REASON = 300;

    private final EventService events;
    private final UserEventRepository eventRepo;
    private final EventApplicationRepository apps;
    private final EventAdmissionService admission;
    private final EventRsvpRepository rsvps;
    private final EventAttendanceRepository attendance;
    private final AttendanceService attendanceService;
    private final CommunityService communities;
    private final AdminCertificateRepository certificates;
    private final EventFeedbackRepository feedback;
    private final AdminFeedbackLookupRepository feedbackLookup;
    private final AdminAnnouncementRepository announcements;
    private final CoOrganizerRepository coOrganizers;

    public EventAdminOpsService(EventService events, UserEventRepository eventRepo, EventApplicationRepository apps,
                                EventAdmissionService admission, EventRsvpRepository rsvps,
                                EventAttendanceRepository attendance, AttendanceService attendanceService,
                                CommunityService communities, AdminCertificateRepository certificates,
                                EventFeedbackRepository feedback, AdminFeedbackLookupRepository feedbackLookup,
                                AdminAnnouncementRepository announcements, CoOrganizerRepository coOrganizers) {
        this.events = events;
        this.eventRepo = eventRepo;
        this.apps = apps;
        this.admission = admission;
        this.rsvps = rsvps;
        this.attendance = attendance;
        this.attendanceService = attendanceService;
        this.communities = communities;
        this.certificates = certificates;
        this.feedback = feedback;
        this.feedbackLookup = feedbackLookup;
        this.announcements = announcements;
        this.coOrganizers = coOrganizers;
    }

    // ================= basvurular =================

    /** Sayfali liste (artan id imeci) + kapasite ozeti. status bos = tum durumlar. */
    @Transactional(readOnly = true)
    public AdminApplicationPage applications(Long eventId, String status, Long cursor, int size) {
        UserEvent e = events.load(eventId);
        EventApplication.Status st = parseStatus(status);
        int s = clamp(size);
        PageRequest page = PageRequest.of(0, s + 1);
        List<EventApplication> rows = st == null
                ? apps.page(eventId, Paging.ascStart(cursor), page)
                : apps.pageByStatus(eventId, st, Paging.ascStart(cursor), page);
        CursorPage<AdminApplicationRow> p = Paging.map(rows, s, EventApplication::getId, items -> applicationRows(items));
        return new AdminApplicationPage(p.items(), p.nextCursor(), summary(e));
    }

    List<AdminApplicationRow> applicationRows(List<EventApplication> items) {
        Map<Long, User> users = communities.usersById(items.stream().map(EventApplication::getUserId).toList());
        return items.stream().map(x -> {
            User u = users.get(x.getUserId());
            return new AdminApplicationRow(x.getId(), x.getUserId(), name(u), u == null ? null : EventAdminMasking.email(u.getEmail()),
                    u == null ? null : u.getDepartment(), x.getStatus(), x.getNote(), x.answers(), x.getQueuedAt(),
                    x.getDecidedBy(), x.getDecidedAt(), x.getDecisionNote(), x.getCreatedAt(), x.getUpdatedAt());
        }).toList();
    }

    @Transactional(readOnly = true)
    public ApplicationSummary summary(UserEvent e) {
        Long id = e.getId();
        int going = eventRepo.goingCount(id);
        Integer cap = e.getCapacity();
        EventAdmission.Mode mode = admission.joinPolicyOf(id);
        return new ApplicationSummary(mode.name(), cap, going, cap == null ? null : Math.max(0, cap - going),
                apps.countByEventIdAndStatus(id, EventApplication.Status.PENDING),
                apps.countByEventIdAndStatus(id, EventApplication.Status.ACCEPTED),
                apps.countByEventIdAndStatus(id, EventApplication.Status.WAITLISTED),
                apps.countByEventIdAndStatus(id, EventApplication.Status.REJECTED),
                apps.countByEventIdAndStatus(id, EventApplication.Status.CANCELLED));
    }

    /**
     * Zorla kabul: kapasite kurali AYNEN gecerlidir (dolu etkinlikte 409 EVENT_FULL, basvuru PENDING kalir). Gecersiz gecis
     * 409 INVALID_APPLICATION_STATE; basvurana bildirim gider. Karar sebebi kullaniciya gosterilmez (yalniz denetim kaydinda).
     */
    public ApplicationDecision accept(Long adminId, Long eventId, Long userId) {
        Actor a = adminActor(adminId);
        DecisionItem it = admission.approveRequest(a, eventId, userId);
        AuditContext.target("EVENT", eventId).summary("basvuru kabul: kullanici " + userId + " -> " + it.status());
        return new ApplicationDecision(it.id(), userId, it.status(), summary(events.load(eventId)));
    }

    /** Zorla ret: kabul edilmis katilimci da cikarilir (koltuk serbest kalir, siradaki terfi eder). */
    public ApplicationDecision reject(Long adminId, Long eventId, Long userId) {
        Actor a = adminActor(adminId);
        DecisionItem it = admission.rejectRequest(a, eventId, userId, null);
        AuditContext.target("EVENT", eventId).summary("basvuru ret: kullanici " + userId + " -> " + it.status());
        return new ApplicationDecision(it.id(), userId, it.status(), summary(events.load(eventId)));
    }

    // ================= yoklama =================

    @Transactional(readOnly = true)
    public AdminAttendanceView attendance(Long eventId) {
        events.load(eventId);
        Map<Long, EventRsvp> going = new HashMap<>();
        rsvps.findByEventIdAndStatus(eventId, EventRsvp.Status.GOING).forEach(r -> going.put(r.getUserId(), r));
        Map<Long, EventAttendance> recs = new HashMap<>();
        attendance.findByEventId(eventId).forEach(r -> recs.put(r.getUserId(), r));
        Map<Long, EventCertificate> certs = new HashMap<>();
        certificates.findByEventId(eventId).forEach(c -> certs.put(c.getUserId(), c));

        Set<Long> ids = new LinkedHashSet<>(going.keySet());
        ids.addAll(recs.keySet());
        boolean truncated = ids.size() > MAX_ATTENDANCE_ROWS;
        Set<Long> userIds = new HashSet<>(ids);
        recs.values().forEach(r -> userIds.add(r.getMarkedBy()));
        Map<Long, User> users = communities.usersById(userIds);

        int present = 0;
        int absent = 0;
        int unmarked = 0;
        int walkIns = 0;
        List<AdminAttendanceRow> rows = new ArrayList<>();
        for (Long uid : ids) {
            EventAttendance r = recs.get(uid);
            boolean isGoing = going.containsKey(uid);
            if (r == null) {
                unmarked++;
            } else if (r.isPresent()) {
                present++;
                if (!isGoing) {
                    walkIns++;
                }
            } else {
                absent++;
            }
            User u = users.get(uid);
            User by = r == null ? null : users.get(r.getMarkedBy());
            EventCertificate c = certs.get(uid);
            rows.add(new AdminAttendanceRow(uid, name(u), u == null ? null : EventAdminMasking.email(u.getEmail()),
                    u == null ? null : u.getDepartment(), isGoing ? "GOING" : "WALK_IN",
                    r == null ? null : r.isPresent(), r == null ? null : r.getMethod(), r == null ? null : r.getMarkedBy(),
                    by == null ? null : by.getDisplayName(), r == null ? null : r.getMarkedAt(), c != null,
                    c != null && c.isRevoked()));
        }
        rows.sort(Comparator.comparing(AdminAttendanceRow::displayName, String.CASE_INSENSITIVE_ORDER)
                .thenComparing(AdminAttendanceRow::userId));
        if (truncated) {
            rows = new ArrayList<>(rows.subList(0, MAX_ATTENDANCE_ROWS));
        }
        return new AdminAttendanceView(rows, new AttendanceSummary(going.size(), present, absent, unmarked, walkIns), truncated);
    }

    /**
     * Elle yoklama duzeltmesi (AttendanceService.mark kurallari: etkinlik ACTIVE, yoklama penceresi acilmis, APPROVAL'da
     * yalniz kabul edilmis katilimci). Sertifika etkisi: kayit "yok" yapilirsa sertifika dogrulamasi gecersiz doner
     * (kayit silinmez), yeniden "var" yapilirsa tekrar gecerli olur; iptal edilmis sertifika gecerli sayilmaz.
     */
    @Transactional
    public AttendanceMarkResult mark(Long adminId, Long eventId, Long userId, boolean present) {
        Actor a = adminActor(adminId);
        attendanceService.mark(a, eventId, userId, present, Instant.now());
        EventCertificate c = certificates.findByEventIdAndUserId(eventId, userId).orElse(null);
        AuditContext.target("EVENT", eventId).summary("yoklama duzeltme: kullanici " + userId + " -> " + (present ? "var" : "yok")
                + (c != null && !present ? " (sertifika gecersiz)" : ""));
        return new AttendanceMarkResult(userId, present, c != null, c != null && !c.isRevoked() && present);
    }

    // ================= sertifikalar =================

    @Transactional(readOnly = true)
    public CursorPage<AdminCertificateRow> certificates(Long eventId, Long cursor, int size) {
        events.load(eventId);
        int s = clamp(size);
        List<EventCertificate> rows = certificates.page(eventId, Paging.ascStart(cursor), PageRequest.of(0, s + 1));
        Map<Long, EventAttendance> recs = new HashMap<>();
        attendance.findByEventId(eventId).forEach(r -> recs.put(r.getUserId(), r));
        return Paging.map(rows, s, EventCertificate::getId, items -> {
            Map<Long, User> users = communities.usersById(items.stream().map(EventCertificate::getUserId).toList());
            return items.stream().map(c -> certRow(c, users.get(c.getUserId()),
                    recs.get(c.getUserId()) != null && recs.get(c.getUserId()).isPresent())).toList();
        });
    }

    /** Sertifikayi iptal eder (satir silinmez; dogrulama gecersiz, kullanici yeniden alamaz). Zaten iptalse 409. */
    @Transactional
    public AdminCertificateRow revokeCertificate(Long adminId, Long eventId, Long userId, String reason) {
        events.load(eventId);
        EventCertificate c = certificates.findByEventIdAndUserId(eventId, userId).orElseThrow(EventAdminOpsService::certNotFound);
        if (c.isRevoked()) {
            throw new ApiException(HttpStatus.CONFLICT, "CERTIFICATE_REVOKED", "Bu sertifika yönetici tarafından iptal edildi.");
        }
        c.setRevokedAt(Instant.now());
        c.setRevokedBy(adminId);
        c.setRevokeReason(clip(Texts.blankToNull(reason)));
        certificates.saveAndFlush(c);
        AuditContext.target("EVENT", eventId).summary("sertifika iptal: kullanici " + userId);
        return certRow(c, communities.usersById(List.of(userId)).get(userId), attended(eventId, userId));
    }

    /** Iptali geri alir (yanlis iptale karsi guvenlik agi). Iptal edilmemisse 409 CERTIFICATE_NOT_REVOKED. */
    @Transactional
    public AdminCertificateRow restoreCertificate(Long adminId, Long eventId, Long userId) {
        events.load(eventId);
        EventCertificate c = certificates.findByEventIdAndUserId(eventId, userId).orElseThrow(EventAdminOpsService::certNotFound);
        if (!c.isRevoked()) {
            throw new ApiException(HttpStatus.CONFLICT, "CERTIFICATE_NOT_REVOKED", "Bu sertifika iptal edilmemiş.");
        }
        c.setRevokedAt(null);
        c.setRevokedBy(null);
        c.setRevokeReason(null);
        certificates.saveAndFlush(c);
        AuditContext.target("EVENT", eventId).summary("sertifika iptali geri alindi: kullanici " + userId);
        return certRow(c, communities.usersById(List.of(userId)).get(userId), attended(eventId, userId));
    }

    private AdminCertificateRow certRow(EventCertificate c, User u, boolean attended) {
        return new AdminCertificateRow(c.getId(), c.getUserId(), c.getHolderName(),
                u == null ? null : EventAdminMasking.email(u.getEmail()), EventAdminMasking.codeHint(c.getCode()),
                c.getIssuedAt(), attended, c.isRevoked(), c.getRevokedAt(), c.getRevokedBy(), c.getRevokeReason(),
                !c.isRevoked() && attended);
    }

    // ================= geri bildirim =================

    /** Geri bildirimler ANONIMDIR: yazan kimligi (id, ad, e-posta) hicbir kosulda donmez. Yeniden eskiye imec. */
    @Transactional(readOnly = true)
    public AdminFeedbackPage feedback(Long eventId, Long cursor, int size) {
        events.load(eventId);
        int s = clamp(size);
        List<EventFeedback> rows = feedback.page(eventId, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        CursorPage<AdminFeedbackRow> p = Paging.map(rows, s, EventFeedback::getId, items -> items.stream()
                .map(f -> new AdminFeedbackRow(f.getId(), f.getRating(), f.getComment(), f.getCreatedAt())).toList());
        long[] dist = new long[5];
        long total = 0;
        long sum = 0;
        for (Object[] row : feedback.distribution(eventId)) {
            int rating = ((Number) row[0]).intValue();
            long n = ((Number) row[1]).longValue();
            if (rating >= 1 && rating <= 5) {
                dist[rating - 1] = n;
                total += n;
                sum += n * rating;
            }
        }
        double avg = total == 0 ? 0 : Math.round(sum * 100.0 / total) / 100.0;
        return new AdminFeedbackPage(p.items(), p.nextCursor(), new FeedbackStats(total, avg, dist));
    }

    /** Geri bildirimi siler (kayit geri alinamaz; yazan yeniden gonderebilir). Yorum metni denetim kaydina yazilmaz. */
    @Transactional
    public void deleteFeedback(Long eventId, Long feedbackId) {
        events.load(eventId);
        EventFeedback f = feedbackLookup.findByIdAndEventId(feedbackId, eventId).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "FEEDBACK_NOT_FOUND", "Geri bildirim bulunamadı."));
        feedbackLookup.delete(f);
        AuditContext.target("EVENT", eventId).summary("geri bildirim #" + feedbackId + " silindi (puan " + f.getRating() + ")");
    }

    // ================= duyurular =================

    @Transactional(readOnly = true)
    public CursorPage<AdminAnnouncementRow> announcements(Long eventId, Long cursor, int size) {
        events.load(eventId);
        int s = clamp(size);
        List<EventAnnouncement> rows = announcements.page(eventId, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, EventAnnouncement::getId, items -> {
            Map<Long, User> users = communities.usersById(items.stream().map(EventAnnouncement::getSenderId).distinct().toList());
            return items.stream().map(x -> new AdminAnnouncementRow(x.getId(), x.getSenderId(), name(users.get(x.getSenderId())),
                    x.getRecipients(), x.getCreatedAt())).toList();
        });
    }

    /**
     * Duyuru KAYDINI siler. Duyuru metni saklanmadigi ve bildirimler gonderildigi icin alicilardaki bildirimler geri alinmaz;
     * kayit gunluk duyuru sinirina da sayildigindan silme, organizatore o gun icin yeniden hak acar.
     */
    @Transactional
    public void deleteAnnouncement(Long eventId, Long announcementId) {
        events.load(eventId);
        EventAnnouncement a = announcements.findByIdAndEventId(announcementId, eventId).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "ANNOUNCEMENT_NOT_FOUND", "Duyuru bulunamadı."));
        announcements.delete(a);
        AuditContext.target("EVENT", eventId).summary("duyuru kaydi #" + announcementId + " silindi (alici " + a.getRecipients() + ")");
    }

    // ================= duzenleyenler =================

    /** Sahip (olusturan) + ortak duzenleyenler; yalniz ortak duzenleyen cikarilabilir. */
    @Transactional(readOnly = true)
    public List<AdminOrganizerRow> organizers(Long eventId) {
        UserEvent e = events.load(eventId);
        List<CoOrganizer> co = coOrganizers.findByEventIdOrderById(eventId);
        Set<Long> ids = new HashSet<>();
        ids.add(e.getCreatedBy());
        co.forEach(c -> ids.add(c.getUserId()));
        Map<Long, User> users = communities.usersById(ids);
        List<AdminOrganizerRow> out = new ArrayList<>();
        User owner = users.get(e.getCreatedBy());
        out.add(new AdminOrganizerRow(e.getCreatedBy(), name(owner), owner == null ? null : EventAdminMasking.email(owner.getEmail()),
                "OWNER", null, e.getCreatedAt(), false));
        for (CoOrganizer c : co) {
            User u = users.get(c.getUserId());
            out.add(new AdminOrganizerRow(c.getUserId(), name(u), u == null ? null : EventAdminMasking.email(u.getEmail()),
                    "CO_ORGANIZER", c.getAddedBy(), c.getCreatedAt(), true));
        }
        return out;
    }

    /**
     * Ortak duzenleyeni cikarir. Sahip cikarilamaz (409 EVENT_OWNER_PROTECTED). Sahip hesabi artik aktif degilse
     * (silinmis/askida) kalan SON aktif duzenleyen de cikarilamaz (409 EVENT_LAST_ORGANIZER): etkinlik sahipsiz kalmasin.
     */
    @Transactional
    public void removeOrganizer(Long eventId, Long userId) {
        UserEvent e = events.load(eventId);
        if (userId.equals(e.getCreatedBy())) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_OWNER_PROTECTED", "Etkinlik sahibi düzenleyenlerden çıkarılamaz.");
        }
        CoOrganizer target = coOrganizers.findByEventIdAndUserId(eventId, userId).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "CO_ORGANIZER_NOT_FOUND", "Ortak organizatör bulunamadı."));
        List<CoOrganizer> others = coOrganizers.findByEventIdOrderById(eventId).stream()
                .filter(c -> !c.getUserId().equals(userId)).toList();
        Set<Long> ids = new HashSet<>();
        ids.add(e.getCreatedBy());
        others.forEach(c -> ids.add(c.getUserId()));
        Map<Long, User> users = communities.usersById(ids);
        boolean ownerActive = isActive(users.get(e.getCreatedBy()));
        boolean otherActive = others.stream().anyMatch(c -> isActive(users.get(c.getUserId())));
        if (!ownerActive && !otherActive) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_LAST_ORGANIZER", "Etkinliğin son aktif düzenleyeni çıkarılamaz.");
        }
        coOrganizers.delete(target);
        AuditContext.target("EVENT", eventId).summary("ortak duzenleyen cikarildi: kullanici " + userId);
    }

    // ================= yardimcilar =================

    /** Kullanici kaydi gerektiren yazmalar icin gercek yonetici hesabi (JWT); Basic auth'ta 403. */
    static Actor adminActor(Long adminId) {
        if (adminId == null) {
            throw new ApiException(HttpStatus.FORBIDDEN, "EVENT_ADMIN_ACCOUNT_REQUIRED",
                    "Bu işlem için kullanıcı hesabıyla giriş yapmış bir yönetici gerekir.");
        }
        return new Actor(adminId, true);
    }

    private boolean attended(Long eventId, Long userId) {
        return attendance.findByEventIdAndUserId(eventId, userId).filter(EventAttendance::isPresent).isPresent();
    }

    private static boolean isActive(User u) {
        return u != null && u.getStatus() == UserStatus.ACTIVE;
    }

    private static String name(User u) {
        return u == null || u.getDisplayName() == null ? "Kullanıcı" : u.getDisplayName();
    }

    private static int clamp(int size) {
        return Math.min(Math.max(size, 1), MAX_PAGE);
    }

    static String clip(String s) {
        return s == null ? null : s.length() > MAX_REASON ? s.substring(0, MAX_REASON) : s;
    }

    private static EventApplication.Status parseStatus(String status) {
        if (status == null || status.isBlank() || status.equalsIgnoreCase("ALL")) {
            return null;
        }
        try {
            return EventApplication.Status.valueOf(status.trim().toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException ex) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
    }

    private static ApiException certNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CERTIFICATE_NOT_FOUND", "Sertifika bulunamadı.");
    }
}
