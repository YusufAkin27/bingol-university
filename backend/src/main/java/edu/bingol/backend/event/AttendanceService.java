package edu.bingol.backend.event;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventAttendance.Method;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRow;
import edu.bingol.backend.event.dto.EventDtos.BulkEntry;
import edu.bingol.backend.event.dto.EventDtos.BulkResult;
import edu.bingol.backend.event.dto.EventDtos.CheckinCode;
import edu.bingol.backend.event.dto.EventDtos.MyAttendance;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yoklama: (1) QR ile kendi kendine giris, (2) organizatorun elle/toplu isaretlemesi. Her kayitta kim, ne zaman,
 * hangi yontemle yazdi tutulur. Yoklama penceresi: baslangic-30dk .. bitis+30dk.
 */
@Service
public class AttendanceService {

    static final Duration WINDOW_BEFORE = Duration.ofMinutes(30);
    static final Duration WINDOW_AFTER = Duration.ofMinutes(30);
    static final int MAX_BULK = 500;

    private final EventService events;
    private final EventRsvpRepository rsvps;
    private final EventAttendanceRepository attendance;
    private final CheckinCodeService codes;
    private final CommunityService communities;

    public AttendanceService(EventService events, EventRsvpRepository rsvps, EventAttendanceRepository attendance,
                             CheckinCodeService codes, CommunityService communities) {
        this.events = events;
        this.rsvps = rsvps;
        this.attendance = attendance;
        this.codes = codes;
        this.communities = communities;
    }

    // ---- QR ----

    /** Organizator icin kisa omurlu kod; yalnizca yoklama penceresinde uretilir. */
    public CheckinCode issueCode(Actor a, Long eventId, Instant now) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        requireActive(e);
        requireWindow(e, now);
        String code = codes.generate(eventId, now);
        return new CheckinCode(code, "bingol-checkin:" + code, codes.expiresAt(now), CheckinCodeService.MAX_VALID_SECONDS);
    }

    /** Katilimci QR kodunu okutur. Idempotent: ikinci okutma mevcut kaydi aynen dondurur. */
    @Transactional
    public MyAttendance checkIn(Actor a, Long eventId, String code, Instant now) {
        UserEvent e = events.loadVisible(a, eventId);
        requireActive(e);
        requireWindow(e, now);
        if (!codes.verify(eventId, code, now)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Yoklama kodu geçersiz veya süresi dolmuş.");
        }
        EventRsvp rsvp = rsvps.findByEventIdAndUserId(eventId, a.id()).orElse(null);
        if (rsvp == null || rsvp.getStatus() != EventRsvp.Status.GOING) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOT_RSVPED", "Yoklama için etkinliğe \"Katılacağım\" demiş olmalısınız.");
        }
        EventAttendance rec = attendance.findByEventIdAndUserId(eventId, a.id()).orElse(null);
        if (rec != null && rec.isPresent()) {
            return toMine(e, rsvp, rec, now);
        }
        if (rec == null) {
            rec = new EventAttendance();
            rec.setEventId(eventId);
            rec.setUserId(a.id());
        }
        // Elle "yok" yazilmis kayit varsa kullanicinin kendi okutmasi bunu duzeltir.
        rec.setPresent(true);
        rec.setMethod(Method.QR);
        rec.setMarkedBy(a.id());
        rec.setMarkedAt(now);
        try {
            attendance.saveAndFlush(rec);
        } catch (DataIntegrityViolationException ex) {
            // Es zamanli cift okutma: islem geri alinir; istemci tekrar denediginde idempotent yanit alir.
            throw new ApiException(HttpStatus.CONFLICT, "CHECKIN_CONFLICT", "Yoklama işleniyor, tekrar deneyin.");
        }
        return toMine(e, rsvp, rec, now);
    }

    @Transactional(readOnly = true)
    public MyAttendance mine(Actor a, Long eventId, Instant now) {
        UserEvent e = events.loadVisible(a, eventId);
        EventRsvp rsvp = rsvps.findByEventIdAndUserId(eventId, a.id()).orElse(null);
        return toMine(e, rsvp, attendance.findByEventIdAndUserId(eventId, a.id()).orElse(null), now);
    }

    // ---- elle yoklama ----

    /** GOING kullanicilar + (varsa) listeye elle eklenen / QR ile gelen diger kullanicilar. */
    @Transactional(readOnly = true)
    public List<AttendanceRow> list(Actor a, Long eventId) {
        events.requireManager(a, events.load(eventId));
        Map<Long, EventRsvp> going = new HashMap<>();
        rsvps.findByEventIdAndStatus(eventId, EventRsvp.Status.GOING).forEach(r -> going.put(r.getUserId(), r));
        Map<Long, EventAttendance> recs = new HashMap<>();
        attendance.findByEventId(eventId).forEach(r -> recs.put(r.getUserId(), r));

        Set<Long> userIds = new HashSet<>(going.keySet());
        userIds.addAll(recs.keySet());
        recs.values().forEach(r -> userIds.add(r.getMarkedBy()));
        Map<Long, User> users = communities.usersById(userIds);

        List<AttendanceRow> rows = new ArrayList<>();
        for (Long uid : unionOf(going.keySet(), recs.keySet())) {
            User u = users.get(uid);
            EventAttendance r = recs.get(uid);
            EventRsvp rsvp = going.get(uid);
            User by = r == null ? null : users.get(r.getMarkedBy());
            rows.add(new AttendanceRow(uid, u == null ? "Kullanıcı" : u.getDisplayName(),
                    u == null ? null : u.getDepartment(), rsvp == null ? null : rsvp.getStatus(),
                    r != null && r.isPresent(), r == null ? null : r.getMethod(), r == null ? null : r.getMarkedBy(),
                    by == null ? null : by.getDisplayName(), r == null ? null : r.getMarkedAt()));
        }
        rows.sort(Comparator.comparing(AttendanceRow::displayName, String.CASE_INSENSITIVE_ORDER)
                .thenComparing(AttendanceRow::userId));
        return rows;
    }

    /** Tek kullaniciyi elle isaretler; RSVP'siz (kapidan gelen) kullanici da eklenebilir. */
    @Transactional
    public void mark(Actor a, Long eventId, Long userId, boolean present, Instant now) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        requireActive(e);
        requireManualOpen(e, now);
        markOne(e, a, userId, present, now);
    }

    @Transactional
    public BulkResult bulk(Actor a, Long eventId, List<BulkEntry> entries, Instant now) {
        if (entries == null || entries.isEmpty() || entries.size() > MAX_BULK) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "Toplu işaretleme 1-" + MAX_BULK + " kayıt içermelidir.");
        }
        UserEvent e = events.requireManager(a, events.load(eventId));
        requireActive(e);
        requireManualOpen(e, now);
        for (BulkEntry en : entries) {
            markOne(e, a, en.userId(), en.present(), now);
        }
        return new BulkResult(entries.size());
    }

    /** Yoklama listesi CSV (UTF-8); hucreler CSV enjeksiyonuna karsi kacirilir. */
    @Transactional(readOnly = true)
    public String csv(Actor a, Long eventId) {
        List<AttendanceRow> rows = list(a, eventId);
        StringBuilder sb = new StringBuilder("userId,name,department,rsvp,present,method,markedBy,markedAt\r\n");
        for (AttendanceRow r : rows) {
            sb.append(cell(String.valueOf(r.userId()))).append(',')
                    .append(cell(r.displayName())).append(',')
                    .append(cell(r.department())).append(',')
                    .append(cell(r.rsvpStatus() == null ? "WALK_IN" : r.rsvpStatus().name())).append(',')
                    .append(cell(r.present() ? "YES" : "NO")).append(',')
                    .append(cell(r.method() == null ? null : r.method().name())).append(',')
                    .append(cell(r.markedByName())).append(',')
                    .append(cell(r.markedAt() == null ? null : r.markedAt().toString())).append("\r\n");
        }
        return sb.toString();
    }

    /**
     * CSV hucresi: her zaman tirnaklanir; = + - @ TAB CR ile baslayan degerlerin onune ' konur
     * (Excel/Sheets formul calistirmasin).
     */
    static String cell(String v) {
        if (v == null) {
            return "\"\"";
        }
        String s = v;
        if (!s.isEmpty() && "=+-@\t\r".indexOf(s.charAt(0)) >= 0) {
            s = "'" + s;
        }
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }

    // ---- ic yardimcilar ----

    private void markOne(UserEvent e, Actor a, Long userId, boolean present, Instant now) {
        User u = communities.usersById(List.of(userId)).get(userId);
        if (u == null || u.getStatus() != UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        EventAttendance rec = attendance.findByEventIdAndUserId(e.getId(), userId).orElseGet(() -> {
            EventAttendance n = new EventAttendance();
            n.setEventId(e.getId());
            n.setUserId(userId);
            return n;
        });
        rec.setPresent(present);
        rec.setMethod(Method.MANUAL);
        rec.setMarkedBy(a.id());
        rec.setMarkedAt(now);
        attendance.save(rec);
    }

    private MyAttendance toMine(UserEvent e, EventRsvp rsvp, EventAttendance rec, Instant now) {
        return new MyAttendance(e.getId(), rsvp == null ? null : rsvp.getStatus(), rec == null ? null : rec.isPresent(),
                rec == null ? null : rec.getMethod(), rec == null ? null : rec.getMarkedAt(),
                e.getStatus() == UserEvent.Status.ACTIVE && inWindow(e, now));
    }

    static boolean inWindow(UserEvent e, Instant now) {
        return !now.isBefore(e.getStartsAt().minus(WINDOW_BEFORE)) && !now.isAfter(e.getEndsAt().plus(WINDOW_AFTER));
    }

    private static void requireWindow(UserEvent e, Instant now) {
        if (!inWindow(e, now)) {
            throw new ApiException(HttpStatus.CONFLICT, "CHECKIN_CLOSED",
                    "Yoklama yalnızca etkinlik saatlerinde (başlangıçtan 30 dk önce - bitişten 30 dk sonra) açıktır.");
        }
    }

    /** Elle yoklama pencere acildiktan sonra serbesttir (organizator gec de duzeltebilsin). */
    private static void requireManualOpen(UserEvent e, Instant now) {
        if (now.isBefore(e.getStartsAt().minus(WINDOW_BEFORE))) {
            throw new ApiException(HttpStatus.CONFLICT, "CHECKIN_CLOSED", "Yoklama henüz açılmadı.");
        }
    }

    private static void requireActive(UserEvent e) {
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "EVENT_NOT_OPEN", "Etkinlik yayında değil.");
        }
    }

    private static Set<Long> unionOf(Set<Long> a, Set<Long> b) {
        Set<Long> s = new HashSet<>(a);
        s.addAll(b);
        return s;
    }
}
