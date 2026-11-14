package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.LiveView;
import edu.bingol.backend.academician.AcademicianDtos.OpenSessionRequest;
import edu.bingol.backend.academician.AcademicianDtos.PendingScanView;
import edu.bingol.backend.academician.AcademicianDtos.RecordView;
import edu.bingol.backend.academician.AcademicianDtos.SessionView;
import edu.bingol.backend.academician.StudentDirectory.Person;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Yoklama oturumlari: acma/kapatma/yeniden acma/silme, "sayilmasin" anahtari, canli ekran (doner kodlar + kayitlar),
 * elle isaretleme (var / izinli / kaldir). Oturum suresi tembel dolar (expires_at); zamanlayici yoktur. Bir derste ayni anda
 * tek canli oturum vardir (yeni acilis oncekini kapatir). Acma, ders satirini kilitleyerek es zamanli acilislari siralar.
 * Yeniden kullanim: yalniz {@code slotId} verilmis ve ayni gun+saat icin oturum varsa o yeniden acilir; slotsuz acilis her zaman
 * yeni oturum acar, tek istisna cift tiklama korumasi (ayni derste son 10 sn icinde acilmis, hala canli, slotsuz oturum).
 */
@Service
public class AcSessionService {

    private static final Logger log = LoggerFactory.getLogger(AcSessionService.class);
    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final int CODES_AHEAD = 3;
    static final Duration DOUBLE_CLICK = Duration.ofSeconds(10);
    private static final long MAX_DAYS_AWAY = 366;

    private final AcademicianGuard guard;
    private final AcSessionRepository sessions;
    private final AcAttendanceRepository attendance;
    private final AcEnrollmentRepository enrollments;
    private final AcCourseSlotRepository slots;
    private final AcCourseRepository courseRepo;
    private final AcScanRequestRepository scanRequests;
    private final LessonCodeService codes;
    private final StudentDirectory directory;
    private final NoticeService notices;
    private final SessionFinalizer finalizer;
    private final AbsenceWarningService warnings;
    private final PendingScanService pendingScans;
    private final AcademicianProperties props;
    private final Clock clock;
    private final TransactionTemplate tx;

    public AcSessionService(AcademicianGuard guard, AcSessionRepository sessions, AcAttendanceRepository attendance,
                            AcEnrollmentRepository enrollments, AcCourseSlotRepository slots, AcCourseRepository courseRepo,
                            AcScanRequestRepository scanRequests, LessonCodeService codes, StudentDirectory directory,
                            NoticeService notices, SessionFinalizer finalizer, AbsenceWarningService warnings,
                            PendingScanService pendingScans, AcademicianProperties props, Clock clock,
                            PlatformTransactionManager tm) {
        this.guard = guard;
        this.sessions = sessions;
        this.attendance = attendance;
        this.enrollments = enrollments;
        this.slots = slots;
        this.courseRepo = courseRepo;
        this.scanRequests = scanRequests;
        this.codes = codes;
        this.directory = directory;
        this.notices = notices;
        this.finalizer = finalizer;
        this.warnings = warnings;
        this.pendingScans = pendingScans;
        this.props = props;
        this.clock = clock;
        this.tx = new TransactionTemplate(tm);
    }

    public SessionView open(Long userId, Long courseId, OpenSessionRequest r) {
        AcCourse course = guard.ownCourse(userId, courseId);
        requireActive(course);
        Instant now = clock.instant();
        LocalDate today = LocalDate.now(clock.withZone(ZONE));
        LocalDate date = r == null || r.lessonDate() == null ? today : r.lessonDate();
        if (Math.abs(date.toEpochDay() - today.toEpochDay()) > MAX_DAYS_AWAY) {
            throw AcErrors.invalid("lessonDate");
        }
        Long slotId = r == null ? null : r.slotId();
        if (slotId != null && !slots.existsByIdAndCourseId(slotId, courseId)) {
            throw AcErrors.invalid("slotId");
        }
        boolean[] reused = {false};
        AcSession s = tx.execute(st -> {
            courseRepo.lockById(courseId); // es zamanli acilislar tek satirda siralanir
            AcSession target = null;
            if (slotId != null) {
                target = sessions.findSameDay(courseId, date, slotId).orElse(null);
            } else {
                AcSession latest = sessions.latestOf(courseId, PageRequest.of(0, 1)).stream().findFirst().orElse(null);
                if (latest != null && latest.getSlotId() == null && latest.getLessonDate().equals(date) && latest.isLive(now)
                        && latest.getOpenedAt().isAfter(now.minus(DOUBLE_CLICK))) {
                    target = latest; // cift tiklama: ayni oturum
                }
            }
            reused[0] = target != null;
            closeOthers(courseId, target == null ? null : target.getId(), now);
            if (target == null) {
                target = new AcSession();
                target.setCourseId(courseId);
                target.setLessonDate(date);
                target.setSlotId(slotId);
                target.setOpenedAt(now);
                target.setExpiresAt(now.plus(props.sessionTtl()));
                target.setStatus(AcSession.Status.OPEN);
            }
            if (!target.isLive(now)) {
                target.setExpiresAt(now.plus(props.sessionTtl()));
                target.setClosedAt(null);
                target.setStatus(AcSession.Status.OPEN);
            }
            return sessions.save(target);
        });
        warnings.recompute(courseId); // otomatik kapanan/yeniden acilan oturum kesinlesmis kumeyi degistirir (yalniz yukselir)
        boolean notified = r != null && Boolean.TRUE.equals(r.notifyStudents()) && notifyAttendanceStarted(course, userId);
        return view(s, now, pendingScans.list(s.getId()), null, reused[0], notified);
    }

    public SessionView close(Long userId, Long sessionId) {
        AcSession s = guard.ownSession(userId, sessionId);
        Instant now = clock.instant();
        finalizer.close(s, now); // kesinlestirme yolu: kosullu kapatma + devamsizlik uyarisi
        return viewWithPending(sessions.findById(sessionId).orElseThrow(AcErrors::sessionNotFound), now);
    }

    /** Yeniden acma: opened_at DEGISMEZ (ogrencinin derse eklenme sirasi hesabi bozulmasin); uyari duzeyi dusurulmez. */
    public SessionView reopen(Long userId, Long sessionId) {
        AcSession s = guard.ownSession(userId, sessionId);
        requireActive(guard.ownCourse(userId, s.getCourseId()));
        Instant now = clock.instant();
        SessionView v = viewWithPending(tx.execute(st -> {
            courseRepo.lockById(s.getCourseId());
            AcSession x = sessions.findById(sessionId).orElseThrow(AcErrors::sessionNotFound);
            closeOthers(x.getCourseId(), x.getId(), now);
            x.setStatus(AcSession.Status.OPEN);
            x.setClosedAt(null);
            x.setExpiresAt(now.plus(props.sessionTtl()));
            return sessions.save(x);
        }), now);
        warnings.recompute(s.getCourseId());
        return v;
    }

    /** Yanlis acilmis oturumun care'si: oturum + yoklama satirlari + bekleyen istekler silinir; uyari duzeyleri sessizce dusebilir. */
    public void delete(Long userId, Long sessionId) {
        AcSession s = guard.ownSession(userId, sessionId);
        tx.executeWithoutResult(st -> {
            attendance.deleteOfSession(sessionId);
            scanRequests.deleteOfSession(sessionId);
            sessions.deleteById(sessionId);
        });
        warnings.recomputeLowering(s.getCourseId(), null);
    }

    /** "Bu yoklamayi devamsizliga sayma" anahtari (idempotent). Kayitlar kalir; sayimlar ve uyarilar yeniden hesaplanir. */
    public SessionView setCounted(Long userId, Long sessionId, boolean counted) {
        AcSession s = guard.ownSession(userId, sessionId);
        if (s.isCounted() != counted) {
            tx.executeWithoutResult(st -> {
                AcSession x = sessions.findById(sessionId).orElseThrow(AcErrors::sessionNotFound);
                x.setCounted(counted);
                sessions.save(x);
            });
            warnings.recomputeLowering(s.getCourseId(), null);
        }
        return viewWithPending(sessions.findById(sessionId).orElseThrow(AcErrors::sessionNotFound), clock.instant());
    }

    public SessionView get(Long userId, Long sessionId) {
        AcSession s = guard.ownSession(userId, sessionId);
        Instant now = clock.instant();
        finalizer.observeExpired(List.of(s), now);
        return viewWithPending(s, now);
    }

    public List<SessionView> list(Long userId, Long courseId) {
        guard.ownCourse(userId, courseId);
        Instant now = clock.instant();
        List<AcSession> rows = sessions.ofCourseNewestFirst(courseId, PageRequest.of(0, 400));
        finalizer.observeExpired(rows, now);
        Map<Long, Integer> pending = new HashMap<>();
        if (!rows.isEmpty()) {
            for (Object[] o : scanRequests.pendingCounts(rows.stream().map(AcSession::getId).toList())) {
                pending.put((Long) o[0], ((Number) o[1]).intValue());
            }
        }
        return rows.stream().map(s -> view(s, now, null, pending.getOrDefault(s.getId(), 0), false, false)).toList();
    }

    /**
     * Canli ekran: oturum acikken guncel + sonraki iki kod; kapali/suresi dolmussa kod verilmez. {@code newRecords} oturumun
     * TUM yoklama satirlarini (kaldirilanlar {@code revoked:true}, izinliler {@code excused:true}) verir; YALNIZ su an derse kayitli
     * ogrenciler. {@code after} kabul edilir ama yok sayilir (kaldirma/geri alma mevcut satiri degistirir; kimlik imeci kacirirdi).
     */
    public LiveView live(Long userId, Long sessionId, Long after) {
        AcSession s = guard.ownSession(userId, sessionId);
        Instant now = clock.instant();
        finalizer.observeExpired(List.of(s), now);
        boolean live = s.isLive(now);
        List<AcAttendance> rows = attendance.allEnrolledOf(sessionId, s.getCourseId(), PageRequest.of(0, EnrollmentService.MAX_ENROLLED));
        Map<Long, Person> people = directory.labels(rows.stream().map(AcAttendance::getStudentId).toList());
        List<RecordView> recs = rows.stream().map(a -> record(a, people.get(a.getStudentId()))).toList();
        return new LiveView(live ? "OPEN" : "CLOSED", now.toEpochMilli(), LessonCodeService.STEP_SECONDS,
                live ? codes.upcoming(sessionId, now, CODES_AHEAD) : List.of(), attendance.countPresentEnrolled(sessionId, s.getCourseId()),
                enrollments.countByCourseId(s.getCourseId()), recs, pendingScans.list(sessionId));
    }

    /**
     * Elle isaretleme (acik ya da kapali oturum, yalniz kendi dersi). {@code excused=true}: ogrenciyi IZINLI yapar (satir yoksa
     * olusturur, kaldirmayi temizler). Aksi halde "var": kaldirilmis ya da izinli satir MANUAL var olur; zaten gecerli satir
     * (QR ya da elle) degismez (idempotent).
     */
    public RecordView mark(Long userId, Long sessionId, Long studentId, boolean excused) {
        AcSession s = guard.ownSession(userId, sessionId);
        if (!enrollments.existsByCourseIdAndStudentId(s.getCourseId(), studentId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "AC_STUDENT_NOT_ENROLLED", "Öğrenci bu derse kayıtlı değil.");
        }
        AcAttendance a;
        try {
            a = tx.execute(st -> {
                AcAttendance x = attendance.findBySessionIdAndStudentId(sessionId, studentId).orElse(null);
                if (x == null) {
                    x = new AcAttendance();
                    x.setSessionId(sessionId);
                    x.setStudentId(studentId);
                } else if (!x.isRevoked() && x.isExcused() == excused) {
                    return x; // zaten istenen durumda
                } else if (!x.isRevoked() && !x.isExcused() && !excused) {
                    return x;
                }
                x.setRevokedAt(null);
                x.setRevokedBy(null);
                x.setExcused(excused);
                x.setMethod(AcAttendance.Method.MANUAL);
                x.setMarkedBy(userId);
                x.setMarkedAt(clock.instant());
                return attendance.saveAndFlush(x);
            });
        } catch (DataIntegrityViolationException dup) {
            a = attendance.findBySessionIdAndStudentId(sessionId, studentId).orElseThrow(() -> dup);
        }
        warnings.recomputeLowering(s.getCourseId(), List.of(studentId)); // duzeltme: duzey duser/yukselir
        return record(a, directory.labels(List.of(studentId)).get(studentId));
    }

    /** Kaydi kaldirir (yumusak: revoked_at; izinli kayit da duz devamsizliga doner); kaydi olmayana no-op. */
    public void unmark(Long userId, Long sessionId, Long studentId) {
        AcSession s = guard.ownSession(userId, sessionId);
        tx.executeWithoutResult(st -> attendance.findBySessionIdAndStudentId(sessionId, studentId).ifPresent(a -> {
            if (!a.isRevoked()) {
                a.setRevokedAt(clock.instant());
                a.setRevokedBy(userId);
                a.setExcused(false);
                attendance.save(a);
            }
        }));
        warnings.recomputeLowering(s.getCourseId(), List.of(studentId));
    }

    // ---- ic ----

    /** true = ATTENDANCE_STARTED gercekten gonderildi. */
    private boolean notifyAttendanceStarted(AcCourse course, Long userId) {
        try {
            notices.autoAttendanceStarted(course, userId);
            return true;
        } catch (ApiException e) {
            // ayni derste 10 dk icinde tekrar: oturum acilisi basarili, yalniz bildirim atlanir
            log.debug("Yoklama bildirimi atlandi courseId={}: {}", course.getId(), e.code());
            return false;
        }
    }

    private void closeOthers(Long courseId, Long exceptId, Instant now) {
        for (AcSession o : sessions.liveOf(courseId, now, PageRequest.of(0, 20))) {
            if (!o.getId().equals(exceptId)) {
                sessions.closeIfOpen(o.getId(), now);
            }
        }
    }

    private static void requireActive(AcCourse c) {
        if (c.getStatus() != AcCourse.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "AC_COURSE_ARCHIVED", "Ders arşivlenmiş; yoklama açılamaz.");
        }
    }

    SessionView viewWithPending(AcSession s, Instant now) {
        return view(s, now, pendingScans.list(s.getId()), null, false, false);
    }

    private SessionView view(AcSession s, Instant now, List<PendingScanView> pending, Integer pendingCount, boolean reused,
                             boolean notified) {
        return new SessionView(s.getId(), s.getCourseId(), s.getSlotId(), s.getLessonDate(), s.getOpenedAt(), s.getExpiresAt(),
                s.getClosedAt(), s.isLive(now) ? "OPEN" : "CLOSED", s.isCounted(),
                attendance.countPresentEnrolled(s.getId(), s.getCourseId()), enrollments.countByCourseId(s.getCourseId()),
                pending != null ? Integer.valueOf(pending.size()) : pendingCount, pending, reused, notified);
    }

    static RecordView record(AcAttendance a, Person p) {
        return new RecordView(a.getId(), a.getStudentId(), p == null ? null : p.displayName(), p == null ? null : p.studentNo(),
                a.getMethod().name(), a.getMarkedAt(), a.isRevoked(), a.isExcused());
    }
}
