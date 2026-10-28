package edu.bingol.backend.event.admin;

import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.Paging;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminApplicationRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAttendanceRow;
import edu.bingol.backend.event.admission.EventAdmission;
import edu.bingol.backend.event.admission.EventAdmissionService;
import edu.bingol.backend.event.admission.EventApplication;
import edu.bingol.backend.event.admission.EventApplicationRepository;
import edu.bingol.backend.user.User;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Yonetici CSV disa aktarimlari (UTF-8 BOM, CRLF, formul kacisli, en cok {@value #MAX_ROWS} satir). Kisisel veri kisitli
 * (KARAR): e-posta HER ZAMAN maskeli; geri bildirim ve sohbet icerigi hicbir CSV'de yoktur. Satirlar bellekte
 * biriktirilmeden parca parca yazilir; yazilan satir sayisi doner (denetim ozeti icin).
 */
@Service
public class EventAdminCsvService {

    public static final int MAX_ROWS = 50_000;
    static final int CHUNK = 500;
    private static final Instant MIN_DATE = Instant.parse("1970-01-01T00:00:00Z");
    private static final Instant FAR_FUTURE = Instant.parse("2100-01-01T00:00:00Z");

    private final EventAdminOpsService ops;
    private final EventApplicationRepository apps;
    private final UserEventRepository eventRepo;
    private final EventAdmissionService admission;
    private final CommunityService communities;

    public EventAdminCsvService(EventAdminOpsService ops, EventApplicationRepository apps, UserEventRepository eventRepo,
                                EventAdmissionService admission, CommunityService communities) {
        this.ops = ops;
        this.apps = apps;
        this.eventRepo = eventRepo;
        this.admission = admission;
        this.communities = communities;
    }

    /** Yoklama listesi. */
    public int attendance(Long eventId, Writer w) {
        List<AdminAttendanceRow> rows = ops.attendance(eventId).rows();
        write(w, Csv.BOM);
        write(w, Csv.row(List.of("userId", "name", "emailMasked", "department", "rsvp", "present", "method", "markedBy",
                "markedAt", "certificate")));
        int n = 0;
        for (AdminAttendanceRow r : rows) {
            if (n >= MAX_ROWS) {
                break;
            }
            write(w, Csv.row(java.util.Arrays.asList(r.userId(), r.displayName(), r.emailMasked(), r.department(), r.rsvp(),
                    r.present() == null ? "" : r.present() ? "YES" : "NO", r.method(), r.markedBy(), r.markedAt(),
                    !r.hasCertificate() ? "" : r.certificateRevoked() ? "REVOKED" : "ISSUED")));
            n++;
        }
        return n;
    }

    /** Basvurular (status bos = tum durumlar). */
    public int applications(Long eventId, String status, Writer w) {
        ops.applications(eventId, status, null, 1); // 404 / gecersiz durum erken (yanit yazilmadan once)
        EventApplication.Status st = parse(status);
        write(w, Csv.BOM);
        write(w, Csv.row(List.of("applicationId", "userId", "name", "emailMasked", "department", "status", "note", "answers",
                "queuedAt", "decidedAt", "decisionNote", "createdAt")));
        int n = 0;
        long cursor = 0;
        while (n < MAX_ROWS) {
            int want = Math.min(CHUNK, MAX_ROWS - n);
            PageRequest page = PageRequest.of(0, want);
            List<EventApplication> rows = st == null ? apps.page(eventId, cursor, page) : apps.pageByStatus(eventId, st, cursor, page);
            if (rows.isEmpty()) {
                break;
            }
            for (AdminApplicationRow r : ops.applicationRows(rows)) {
                write(w, Csv.row(java.util.Arrays.asList(r.id(), r.userId(), r.displayName(), r.emailMasked(), r.department(),
                        r.status(), r.note(), String.join(" | ", r.answers()), r.queuedAt(), r.decidedAt(), r.decisionNote(),
                        r.createdAt())));
                n++;
            }
            cursor = rows.get(rows.size() - 1).getId();
            if (rows.size() < want) {
                break;
            }
        }
        return n;
    }

    /** Etkinlik listesi: GET /api/admin/events ile ayni suzgecler; status bos = ALL (liste ucundaki PENDING_REVIEW varsayilani yok). */
    public int events(String status, String q, Long communityId, boolean standalone, EventAdmission.Mode joinPolicy,
                      Instant from, Instant to, Writer w) {
        boolean any = false;
        UserEvent.Status st = UserEvent.Status.PENDING_REVIEW;
        if (status == null || status.isBlank() || status.equalsIgnoreCase("ALL")) {
            any = true;
        } else {
            try {
                st = UserEvent.Status.valueOf(status.trim().toUpperCase(Locale.ROOT));
            } catch (IllegalArgumentException ex) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
            }
        }
        Instant f = from == null ? MIN_DATE : from;
        Instant t = to == null ? FAR_FUTURE : to;
        if (!t.isAfter(f)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_DATES", "Tarih aralığı geçersiz.");
        }
        String like = likePattern(q);
        int policy = joinPolicy == null ? 0 : joinPolicy == EventAdmission.Mode.OPEN ? 1 : 2;

        write(w, Csv.BOM);
        write(w, Csv.row(List.of("id", "title", "status", "startsAt", "endsAt", "location", "capacity", "goingCount",
                "communityId", "organizerId", "organizerName", "organizerEmailMasked", "joinPolicy", "registrationClosed",
                "createdAt")));
        int n = 0;
        Long cursor = null;
        while (n < MAX_ROWS) {
            List<UserEvent> rows = eventRepo.adminSearch(any, st, communityId == null ? 0L : communityId, standalone, f, t,
                    policy, like != null, like == null ? "" : like, Paging.descStart(cursor),
                    PageRequest.of(0, Math.min(CHUNK, MAX_ROWS - n)));
            if (rows.isEmpty()) {
                break;
            }
            Map<Long, User> owners = communities.usersById(rows.stream().map(UserEvent::getCreatedBy).distinct().toList());
            Map<Long, EventAdmission.Mode> modes = admission.joinPolicies(rows.stream().map(UserEvent::getId).toList());
            for (UserEvent e : rows) {
                User o = owners.get(e.getCreatedBy());
                write(w, Csv.row(java.util.Arrays.asList(e.getId(), e.getTitle(), e.getStatus(), e.getStartsAt(), e.getEndsAt(),
                        e.getLocation(), e.getCapacity(), e.getGoingCount(), e.getCommunityId(), e.getCreatedBy(),
                        o == null ? null : o.getDisplayName(), o == null ? null : EventAdminMasking.email(o.getEmail()),
                        modes.getOrDefault(e.getId(), EventAdmission.Mode.OPEN), e.isRegistrationClosed(), e.getCreatedAt())));
                n++;
            }
            cursor = rows.get(rows.size() - 1).getId();
        }
        return n;
    }

    /** Turkce katlama (I/i/ı/İ -> i), LIKE ozel karakterleri '!' ile kacirilir (EventModerationService.likePattern ile ayni kural). */
    static String likePattern(String q) {
        if (q == null || q.isBlank()) {
            return null;
        }
        String t = q.trim();
        if (t.length() > 100) {
            t = t.substring(0, 100);
        }
        t = t.replace('İ', 'i').replace('I', 'i').replace('ı', 'i').toLowerCase(Locale.ROOT)
                .replace("!", "!!").replace("%", "!%").replace("_", "!_");
        return "%" + t + "%";
    }

    private static EventApplication.Status parse(String status) {
        if (status == null || status.isBlank() || status.equalsIgnoreCase("ALL")) {
            return null;
        }
        return EventApplication.Status.valueOf(status.trim().toUpperCase(Locale.ROOT));
    }

    private static void write(Writer w, String s) {
        try {
            w.write(s);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
