package edu.bingol.backend.event;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventAttendance.Method;
import edu.bingol.backend.event.admission.EventAdmissionHooks;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRoster;
import edu.bingol.backend.event.dto.EventDtos.AttendanceSummary;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRow;
import edu.bingol.backend.event.dto.EventDtos.BulkEntry;
import edu.bingol.backend.event.dto.EventDtos.BulkResult;
import edu.bingol.backend.event.dto.EventDtos.CheckinCode;
import edu.bingol.backend.event.dto.EventDtos.MyAttendance;
import edu.bingol.backend.event.dto.EventDtos.MyTicket;
import edu.bingol.backend.event.dto.EventDtos.ScanResult;
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
import java.util.function.Supplier;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
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

    /** Gercek zamanli okutma olaylari (null iken yayin yok: birim testler). */
    private AttendanceLiveEvents live;

    @Autowired
    public void setLive(@Lazy AttendanceLiveEvents live) {
        this.live = live;
    }

    private void publishScanned(UserEvent e, Long userId, String name, Instant at) {
        if (live != null) {
            live.scanned(e, userId, name, at);
        }
    }

    /** T9: APPROVAL modunda elle yoklama yalnizca kabul edilmis katilimciya (null iken eski davranis). */
    private EventAdmissionHooks admission;

    @Autowired
    public void setAdmission(@Lazy EventAdmissionHooks admission) {
        this.admission = admission;
    }

    // ---- QR ----

    /** Organizator icin kisa omurlu kod; yalnizca yoklama penceresinde uretilir. */
    public CheckinCode issueCode(Actor a, Long eventId, Instant now) {
        UserEvent e = events.requireManager(a, events.load(eventId));
        requireActive(e);
        if (!e.isAttendanceOpen()) {
            requireWindow(e, now); // sahip anahtari acmadiysa yalniz pencere icinde
        }
        String code = codes.generate(eventId, now);
        return new CheckinCode(code, "bingol-checkin:" + code, codes.expiresAt(now), CheckinCodeService.MAX_VALID_SECONDS,
                codes.generateManual(eventId, now));
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
        publishScanned(e, a.id(), displayNameOf(a.id()), now);
        return toMine(e, rsvp, rec, now);
    }

    // ---- katilimci bileti + organizator tarayicisi ----

    /**
     * Onayli (GOING) katilimciya kisisel QR. Etkinlik baslamadan da gosterilebilir (okutma yalniz yoklama penceresinde).
     * Katilimci olmayan / bekleyen / reddedilen kullanici 403 NOT_RSVPED alir.
     */
    @Transactional(readOnly = true)
    public MyTicket issueTicket(Actor a, Long eventId, Instant now) {
        UserEvent e = events.loadVisible(a, eventId);
        requireActive(e);
        // Yoklamayi alanlar (sahip/yonetici/moderator) QR uretmez; yalniz onayli katilimci QR uretir.
        if (events.canManage(a, e) || (moderators != null && moderators.isModerator(e, a.id()))) {
            throw new ApiException(HttpStatus.FORBIDDEN, "TICKET_NOT_FOR_STAFF",
                    "Yoklamayı alanlar için kişisel QR kodu yoktur; katılımcıların QR kodunu okutursunuz.");
        }
        EventRsvp rsvp = rsvps.findByEventIdAndUserId(eventId, a.id()).orElse(null);
        if (rsvp == null || rsvp.getStatus() != EventRsvp.Status.GOING) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOT_RSVPED", "Yoklama için etkinliğe \"Katılacağım\" demiş olmalısınız.");
        }
        requireAttendanceOpen(e, now);
        String code = codes.generateTicket(eventId, a.id(), now);
        return new MyTicket(code, CheckinCodeService.TICKET_PREFIX + code, codes.ticketExpiresAt(now),
                CheckinCodeService.TICKET_VALID_SECONDS);
    }

    /**
     * Organizator/moderator: katilimcinin QR'ini okutur ve yoklamayi isler. Cok okutucu: ayni kisi iki okutucuda ayni
     * anda okutulursa benzersiz kisit biri icin CHECKIN_CONFLICT dondurur; islem yeni transaction'da bir kez tekrarlanir
     * ve ikinci okutucu "ALREADY" alir (tek kayit).
     */
    public ScanResult scan(Actor a, Long eventId, String payload, Instant now) {
        return retryOnConflict(() -> self().scanOnce(a, eventId, payload, now));
    }

    private AttendanceService self;

    @Autowired
    public void setSelf(@Lazy AttendanceService self) {
        this.self = self;
    }

    private AttendanceService self() {
        return self != null ? self : this;
    }

    private static <T> T retryOnConflict(Supplier<T> op) {
        try {
            return op.get();
        } catch (ApiException ex) {
            if (!"CHECKIN_CONFLICT".equals(ex.code())) {
                throw ex;
            }
            return op.get();
        }
    }

    @Transactional
    public ScanResult scanOnce(Actor a, Long eventId, String payload, Instant now) {
        UserEvent e = access(a, eventId, EventModerator.Perm.TAKE_ATTENDANCE);
        requireActive(e);
        requireAttendanceOpen(e, now);
        requireWindow(e, now);
        long uid = codes.verifyTicket(eventId, payload, now);
        if (uid < 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_CODE", "Yoklama kodu geçersiz veya süresi dolmuş.");
        }
        User u = communities.usersById(List.of(uid)).get(uid);
        if (u == null || u.getStatus() != UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        EventRsvp rsvp = rsvps.findByEventIdAndUserId(eventId, uid).orElse(null);
        if (rsvp == null || rsvp.getStatus() != EventRsvp.Status.GOING) {
            // Katilimdan sonra vazgecmis / iptal edilmis olabilir: eski QR ile giris yok.
            throw new ApiException(HttpStatus.CONFLICT, "NOT_RSVPED_SCAN", "Bu kişi etkinliğe onaylı katılımcı değil.");
        }
        String name = u.getDisplayName() == null ? "Kullanıcı" : u.getDisplayName();
        EventAttendance rec = attendance.findByEventIdAndUserId(eventId, uid).orElse(null);
        if (rec != null && rec.isPresent()) {
            return new ScanResult("ALREADY", uid, name, rec.getMarkedAt());
        }
        if (rec == null) {
            rec = new EventAttendance();
            rec.setEventId(eventId);
            rec.setUserId(uid);
        }
        rec.setPresent(true);
        rec.setMethod(Method.QR);
        rec.setMarkedBy(a.id());
        rec.setMarkedAt(now);
        try {
            attendance.saveAndFlush(rec);
        } catch (DataIntegrityViolationException ex) {
            throw new ApiException(HttpStatus.CONFLICT, "CHECKIN_CONFLICT", "Yoklama işleniyor, tekrar deneyin.");
        }
        publishScanned(e, uid, name, now);
        return new ScanResult("MARKED", uid, name, now);
    }

    private String displayNameOf(Long uid) {
        User u = communities.usersById(List.of(uid)).get(uid);
        return u == null || u.getDisplayName() == null ? "Kullanıcı" : u.getDisplayName();
    }

    /**
     * Organizator/yetkili canli sayaci: yoklamada n / toplam onayli + son okutan. Gercek zamanli olay kacirilirse
     * istemcinin yedek yoklamasi (poll). Engel iliskisi olan son okutanin adi gizlenir.
     */
    @Transactional(readOnly = true)
    public AttendanceSummary summary(Actor a, Long eventId) {
        access(a, eventId, EventModerator.Perm.VIEW_ATTENDEES, EventModerator.Perm.TAKE_ATTENDANCE);
        long present = attendance.countByEventIdAndPresentTrue(eventId);
        long total = rsvps.countByEventIdAndStatus(eventId, EventRsvp.Status.GOING);
        EventAttendance last = attendance.findFirstByEventIdAndPresentTrueOrderByMarkedAtDesc(eventId).orElse(null);
        String lastName = null;
        Instant lastAt = null;
        if (last != null) {
            lastAt = last.getMarkedAt();
            if (!communities.blockedFor(a).contains(last.getUserId())) {
                lastName = displayNameOf(last.getUserId());
            }
        }
        return new AttendanceSummary(present, total, lastName, lastAt);
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
        access(a, eventId, EventModerator.Perm.VIEW_ATTENDEES, EventModerator.Perm.TAKE_ATTENDANCE);
        Map<Long, EventRsvp> going = new HashMap<>();
        rsvps.findByEventIdAndStatus(eventId, EventRsvp.Status.GOING).forEach(r -> going.put(r.getUserId(), r));
        Map<Long, EventAttendance> recs = new HashMap<>();
        attendance.findByEventId(eventId).forEach(r -> recs.put(r.getUserId(), r));

        Set<Long> userIds = new HashSet<>(going.keySet());
        userIds.addAll(recs.keySet());
        recs.values().forEach(r -> userIds.add(r.getMarkedBy()));
        Map<Long, User> users = communities.usersById(userIds);
        // T-044: engel iliskisi olan cift listede gorunmez; bolum yalniz sahibinin gizlilik ayari izin veriyorsa
        Set<Long> blocked = communities.blockedFor(a);
        Map<Long, CommunityService.ProfileExtra> extras = communities.profileExtras(a.id(), users.values(), blocked);

        List<AttendanceRow> rows = new ArrayList<>();
        for (Long uid : unionOf(going.keySet(), recs.keySet())) {
            if (blocked.contains(uid)) {
                continue;
            }
            User u = users.get(uid);
            EventAttendance r = recs.get(uid);
            EventRsvp rsvp = going.get(uid);
            User by = r == null ? null : users.get(r.getMarkedBy());
            rows.add(new AttendanceRow(uid, u == null || u.getDisplayName() == null ? "Kullanıcı" : u.getDisplayName(),
                    extras.getOrDefault(uid, CommunityService.ProfileExtra.NONE).department(),
                    rsvp == null ? null : rsvp.getStatus(),
                    r != null && r.isPresent(), r == null ? null : r.getMethod(), r == null ? null : r.getMarkedBy(),
                    by == null ? null : by.getDisplayName(), r == null ? null : r.getMarkedAt(),
                    r == null ? "NONE" : r.isPresent() ? "PRESENT" : "ABSENT"));
        }
        rows.sort(Comparator.comparing(AttendanceRow::displayName, String.CASE_INSENSITIVE_ORDER)
                .thenComparing(AttendanceRow::userId));
        return rows;
    }

    /**
     * Tek kullaniciyi elle isaretler. T-044: yalniz bu etkinlikte GOING olan (ya da zaten yoklama kaydi olan) kullanici;
     * RSVP'siz keyfi kullanici kimligine sahte yoklama ve ad/bolum sizintisi olmasin (olmayan kimlikle ayni 404).
     */
    public void mark(Actor a, Long eventId, Long userId, boolean present, Instant now) {
        mark(a, eventId, userId, present ? "PRESENT" : "ABSENT", now);
    }

    /** status: PRESENT | ABSENT | NONE (kaydi siler: bekliyor). Elle isaretleme pencere acildiktan sonra (etkinlik bitince de) serbesttir. */
    public void mark(Actor a, Long eventId, Long userId, String status, Instant now) {
        String st = parseStatus(status);
        retryOnConflict(() -> {
            self().markTx(a, eventId, userId, st, now);
            return null;
        });
    }

    @Transactional
    public void markTx(Actor a, Long eventId, Long userId, String st, Instant now) {
        UserEvent e = access(a, eventId, EventModerator.Perm.TAKE_ATTENDANCE);
        requireActive(e);
        requireManualOpen(e, now);
        markOne(e, a, userId, st, now);
    }

    public BulkResult bulk(Actor a, Long eventId, List<BulkEntry> entries, Instant now) {
        if (entries == null || entries.isEmpty() || entries.size() > MAX_BULK) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "Toplu işaretleme 1-" + MAX_BULK + " kayıt içermelidir.");
        }
        return retryOnConflict(() -> self().bulkTx(a, eventId, entries, null, null, false, now));
    }

    /** Yeni toplu: status + (userIds | rest = hala bekleyen tum onayli katilimcilar). */
    public BulkResult bulkStatus(Actor a, Long eventId, String status, List<Long> userIds, boolean rest, Instant now) {
        String st = parseStatus(status);
        if (!rest && (userIds == null || userIds.isEmpty() || userIds.size() > MAX_BULK)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "Toplu işaretleme 1-" + MAX_BULK + " kayıt içermelidir.");
        }
        return retryOnConflict(() -> self().bulkTx(a, eventId, null, st, userIds, rest, now));
    }

    @Transactional
    public BulkResult bulkTx(Actor a, Long eventId, List<BulkEntry> entries, String st, List<Long> userIds, boolean rest,
                             Instant now) {
        UserEvent e = access(a, eventId, EventModerator.Perm.TAKE_ATTENDANCE);
        requireActive(e);
        requireManualOpen(e, now);
        int n = 0;
        if (entries != null) {
            for (BulkEntry en : entries) {
                markOne(e, a, en.userId(), en.present() ? "PRESENT" : "ABSENT", now);
                n++;
            }
            return new BulkResult(n);
        }
        List<Long> targets = new ArrayList<>();
        if (rest) {
            // "Kalanlar": onayli katilimcilardan henuz kaydi olmayanlar (bekleyenler).
            Set<Long> recorded = new HashSet<>();
            attendance.findByEventId(eventId).forEach(r -> recorded.add(r.getUserId()));
            for (EventRsvp r : rsvps.findByEventIdAndStatus(eventId, EventRsvp.Status.GOING)) {
                if (!recorded.contains(r.getUserId())) {
                    targets.add(r.getUserId());
                }
            }
            if (targets.size() > 5000) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Çok fazla kayıt.");
            }
        } else {
            targets.addAll(userIds);
        }
        for (Long uid : targets) {
            markOne(e, a, uid, st, now);
            n++;
        }
        return new BulkResult(n);
    }

    private static String parseStatus(String s) {
        String v = s == null ? "" : s.trim().toUpperCase(java.util.Locale.ROOT);
        if (!v.equals("PRESENT") && !v.equals("ABSENT") && !v.equals("NONE")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz yoklama durumu.");
        }
        return v;
    }

    /** Liste + sayaclar: onayli (GOING) katilimcilar uzerinden geldi/gelmedi/bekliyor. */
    @Transactional(readOnly = true)
    public AttendanceRoster roster(Actor a, Long eventId) {
        List<AttendanceRow> rows = list(a, eventId);
        int p = 0, ab = 0, pe = 0, tot = 0;
        for (AttendanceRow r : rows) {
            if (r.rsvpStatus() != EventRsvp.Status.GOING && "NONE".equals(r.status())) {
                continue;
            }
            tot++;
            switch (r.status()) {
                case "PRESENT" -> p++;
                case "ABSENT" -> ab++;
                default -> pe++;
            }
        }
        return new AttendanceRoster(rows, p, ab, pe, tot);
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

    private void markOne(UserEvent e, Actor a, Long userId, String st, Instant now) {
        User u = communities.usersById(List.of(userId)).get(userId);
        if (u == null || u.getStatus() != UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        boolean hasRecord = attendance.findByEventIdAndUserId(e.getId(), userId).isPresent();
        boolean going = rsvps.findByEventIdAndUserId(e.getId(), userId)
                .map(r -> r.getStatus() == EventRsvp.Status.GOING).orElse(false);
        if (!hasRecord && !going) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        if (admission != null) {
            admission.requireEligibleForMark(e, userId);
        }
        EventAttendance existing = attendance.findByEventIdAndUserId(e.getId(), userId).orElse(null);
        if ("NONE".equals(st)) {
            if (existing != null) {
                attendance.delete(existing);
                attendance.flush();
            }
            return;
        }
        boolean present = "PRESENT".equals(st);
        if (existing != null && existing.isPresent() && present) {
            return; // zaten geldi (QR ya da elle): kaynak/okutan korunur
        }
        EventAttendance rec = existing != null ? existing : new EventAttendance();
        rec.setEventId(e.getId());
        rec.setUserId(userId);
        rec.setPresent(present);
        rec.setMethod(Method.MANUAL);
        rec.setMarkedBy(a.id());
        rec.setMarkedAt(now);
        try {
            attendance.saveAndFlush(rec);
        } catch (DataIntegrityViolationException ex) {
            // Es zamanli ilk kayit (QR okutma ile elle isaretleme yarisi): 500 yerine tekrar denenebilir 409.
            throw new ApiException(HttpStatus.CONFLICT, "CHECKIN_CONFLICT", "Yoklama işleniyor, tekrar deneyin.");
        }
    }

    private MyAttendance toMine(UserEvent e, EventRsvp rsvp, EventAttendance rec, Instant now) {
        return new MyAttendance(e.getId(), rsvp == null ? null : rsvp.getStatus(), rec == null ? null : rec.isPresent(),
                rec == null ? null : rec.getMethod(), rec == null ? null : rec.getMarkedAt(),
                e.getStatus() == UserEvent.Status.ACTIVE && (e.isAttendanceOpen() || inWindow(e, now)));
    }

    static boolean inWindow(UserEvent e, Instant now) {
        return !now.isBefore(e.getStartsAt().minus(WINDOW_BEFORE)) && !now.isAfter(e.getEndsAt().plus(WINDOW_AFTER));
    }

    /**
     * Yoklama kurali: sahip yoklamayi ACTIYSA 30 dk penceresi UYGULANMAZ (sahip her an acabilir/yoklama alinabilir);
     * hic acmadiysa pencere (baslangic-30dk .. bitis+30dk) kendiliginden acar.
     */
    private static void requireWindow(UserEvent e, Instant now) {
        if (e.isAttendanceOpen()) {
            return;
        }
        if (!inWindow(e, now)) {
            throw new ApiException(HttpStatus.CONFLICT, "CHECKIN_CLOSED",
                    "Yoklama yalnızca etkinlik saatlerinde (başlangıçtan 30 dk önce - bitişten 30 dk sonra) açıktır.");
        }
    }

    /** Elle yoklama pencere acildiktan sonra serbesttir (organizator gec de duzeltebilsin). */
    private static void requireManualOpen(UserEvent e, Instant now) {
        if (e.isAttendanceOpen()) {
            return; // sahip acmis: pencere kurali yok
        }
        if (now.isBefore(e.getStartsAt().minus(WINDOW_BEFORE))) {
            throw new ApiException(HttpStatus.CONFLICT, "CHECKIN_CLOSED", "Yoklama henüz açılmadı.");
        }
    }

    /** Sahip yoklamayi acmadiysa kisisel QR gosterilmez ve okutma reddedilir. */
    /** Sahip anahtari acmissa ya da yoklama penceresindeyse (baslangic-30dk .. bitis+30dk) yoklama acik sayilir. */
    private static void requireAttendanceOpen(UserEvent e, Instant now) {
        if (!e.isAttendanceOpen() && !inWindow(e, now)) {
            throw new ApiException(HttpStatus.CONFLICT, "ATTENDANCE_NOT_OPEN", "Etkinlik sahibi yoklamayı henüz açmadı.");
        }
    }

    /** Sahip (ya da sistem yoneticisi) veya verilen yetkilerden birine sahip moderator; digerleri 403 EVENT_PERMISSION_DENIED. */
    private UserEvent access(Actor a, Long eventId, EventModerator.Perm... perms) {
        UserEvent e = events.load(eventId);
        if (moderators != null && !events.canManage(a, e)) {
            for (EventModerator.Perm p : perms) {
                if (moderators.has(e, a.id(), p)) {
                    events.loadVisible(a, eventId);
                    return e;
                }
            }
            if (moderators.isModerator(e, a.id())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "EVENT_PERMISSION_DENIED", "Bu işlem için yetkiniz yok.");
            }
        }
        return events.requireManager(a, e);
    }

    private EventModeratorService moderators;

    @Autowired
    public void setModerators(@Lazy EventModeratorService moderators) {
        this.moderators = moderators;
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
