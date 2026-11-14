package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.LiveView;
import edu.bingol.backend.academician.AcademicianDtos.OpenSessionRequest;
import edu.bingol.backend.academician.AcademicianDtos.RecordView;
import edu.bingol.backend.academician.AcademicianDtos.SessionView;
import edu.bingol.backend.academician.StudentDirectory.Person;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
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
 * Yoklama oturumlari: acma/kapatma/yeniden acma, canli ekran (doner kodlar + yeni kayitlar), elle isaretleme.
 * Oturum suresi tembel dolar (expires_at); zamanlayici yoktur. Bir derste ayni anda tek canli oturum vardir
 * (yeni acilis oncekini kapatir). Ayni gun + ayni saat icin oturum varsa yenisi acilmaz, o yeniden acilir (ders
 * ayni gun iki kez sayilmasin).
 */
@Service
public class AcSessionService {

    private static final Logger log = LoggerFactory.getLogger(AcSessionService.class);
    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final int CODES_AHEAD = 3;
    private static final long MAX_DAYS_AWAY = 366;

    private final AcademicianGuard guard;
    private final AcSessionRepository sessions;
    private final AcAttendanceRepository attendance;
    private final AcEnrollmentRepository enrollments;
    private final AcCourseSlotRepository slots;
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
                          AcEnrollmentRepository enrollments, AcCourseSlotRepository slots, LessonCodeService codes,
                          StudentDirectory directory, NoticeService notices, SessionFinalizer finalizer,
                          AbsenceWarningService warnings, PendingScanService pendingScans, AcademicianProperties props,
                          Clock clock,
                          PlatformTransactionManager tm) {
        this.guard = guard;
        this.sessions = sessions;
        this.attendance = attendance;
        this.enrollments = enrollments;
        this.slots = slots;
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
        AcSession s = tx.execute(st -> {
            AcSession existing = sessions.findSameDay(courseId, date, slotId).orElse(null);
            AcSession target = existing != null ? existing : new AcSession();
            closeOthers(courseId, existing == null ? null : existing.getId(), now);
            if (existing == null) {
                target.setCourseId(courseId);
                target.setLessonDate(date);
                target.setSlotId(slotId);
            }
            target.setOpenedAt(now);
            target.setExpiresAt(now.plus(props.sessionTtl()));
            target.setClosedAt(null);
            target.setStatus(AcSession.Status.OPEN);
            return sessions.save(target);
        });
        warnings.recompute(courseId); // yeniden acilan/otomatik kapanan oturum kesinlesmis kumeyi degistirir
        if (r != null && Boolean.TRUE.equals(r.notifyStudents())) {
            notifyAttendanceStarted(course, userId);
        }
        return viewWithPending(s, now);
    }

    public SessionView close(Long userId, Long sessionId) {
        AcSession s = guard.ownSession(userId, sessionId);
        Instant now = clock.instant();
        finalizer.close(s, now); // kesinlestirme yolu: kosullu kapatma + devamsizlik uyarisi
        return viewWithPending(sessions.findById(sessionId).orElseThrow(AcErrors::sessionNotFound), now);
    }

    public SessionView reopen(Long userId, Long sessionId) {
        AcSession s = guard.ownSession(userId, sessionId);
        requireActive(guard.ownCourse(userId, s.getCourseId()));
        Instant now = clock.instant();
        SessionView v = viewWithPending(tx.execute(st -> {
            AcSession x = sessions.findById(sessionId).orElseThrow(AcErrors::sessionNotFound);
            closeOthers(x.getCourseId(), x.getId(), now);
            x.setStatus(AcSession.Status.OPEN);
            x.setClosedAt(null);
            x.setOpenedAt(now);
            x.setExpiresAt(now.plus(props.sessionTtl()));
            return sessions.save(x);
        }), now);
        warnings.recompute(s.getCourseId());
        return v;
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
        return rows.stream().map(s -> view(s, now)).toList();
    }

    /**
     * Canli ekran: oturum acikken guncel + sonraki iki kod; kapali/suresi dolmussa kod verilmez. {@code newRecords} oturumun
     * TUM yoklama satirlarini (kaldirilanlar {@code revoked:true}) verir; {@code after} kabul edilir ama yok sayilir. Neden:
     * kaldirma/geri alma mevcut satiri degistirir, kimlik imeci bunu kacirirdi; kayit sayisi sinirli (en cok 2000) oldugundan
     * tam liste her yoklamada guvenli ve basittir. Istemci kimlige gore birlestirir.
     */
    public LiveView live(Long userId, Long sessionId, Long after) {
        AcSession s = guard.ownSession(userId, sessionId);
        Instant now = clock.instant();
        finalizer.observeExpired(List.of(s), now);
        boolean live = s.isLive(now);
        List<AcAttendance> rows = attendance.allOf(sessionId, PageRequest.of(0, EnrollmentService.MAX_ENROLLED));
        Map<Long, Person> people = directory.labels(rows.stream().map(AcAttendance::getStudentId).toList());
        List<RecordView> recs = rows.stream().map(a -> record(a, people.get(a.getStudentId()))).toList();
        return new LiveView(live ? "OPEN" : "CLOSED", now.toEpochMilli(), LessonCodeService.STEP_SECONDS,
                live ? codes.upcoming(sessionId, now, CODES_AHEAD) : List.of(), attendance.countActive(sessionId),
                enrollments.countByCourseId(s.getCourseId()), recs, pendingScans.list(sessionId));
    }

    /**
     * Elle "var" (oturum acik ya da kapali, yalniz kendi dersi): kaldirilmis satir geri gelir (MANUAL, marked_by = hoca);
     * zaten gecerli satir (QR ya da elle) degismez (idempotent).
     */
    public RecordView mark(Long userId, Long sessionId, Long studentId) {
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
                    x.setMethod(AcAttendance.Method.MANUAL);
                    x.setMarkedBy(userId);
                    x.setMarkedAt(clock.instant());
                } else if (x.isRevoked()) {
                    x.setRevokedAt(null);
                    x.setRevokedBy(null);
                    x.setMethod(AcAttendance.Method.MANUAL);
                    x.setMarkedBy(userId);
                    x.setMarkedAt(clock.instant());
                } else {
                    return x;
                }
                return attendance.saveAndFlush(x);
            });
        } catch (DataIntegrityViolationException dup) {
            a = attendance.findBySessionIdAndStudentId(sessionId, studentId).orElseThrow(() -> dup);
        }
        warnings.recompute(s.getCourseId(), List.of(studentId)); // duzeltme: duzey duser/yukselir
        return record(a, directory.labels(List.of(studentId)).get(studentId));
    }

    /** Kaydi kaldirir (yumusak: revoked_at); kaydi olmayan ogrenci icin no-op. Kaldirilan ogrenci ayni oturumda tekrar tarayamaz. */
    public void unmark(Long userId, Long sessionId, Long studentId) {
        AcSession s = guard.ownSession(userId, sessionId);
        tx.executeWithoutResult(st -> attendance.findBySessionIdAndStudentId(sessionId, studentId).ifPresent(a -> {
            if (!a.isRevoked()) {
                a.setRevokedAt(clock.instant());
                a.setRevokedBy(userId);
                attendance.save(a);
            }
        }));
        warnings.recompute(s.getCourseId(), List.of(studentId));
    }

    // ---- ic ----

    private void notifyAttendanceStarted(AcCourse course, Long userId) {
        try {
            notices.autoAttendanceStarted(course, userId);
        } catch (ApiException e) {
            // ayni derste 10 dk icinde tekrar: oturum acilisi basarili, yalniz bildirim atlanir
            log.debug("Yoklama bildirimi atlandi courseId={}: {}", course.getId(), e.code());
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

    /** Liste ucu icin: pendingScans gonderilmez (null). */
    SessionView view(AcSession s, Instant now) {
        return view(s, now, null);
    }

    SessionView viewWithPending(AcSession s, Instant now) {
        return view(s, now, pendingScans.list(s.getId()));
    }

    private SessionView view(AcSession s, Instant now, List<AcademicianDtos.PendingScanView> pending) {
        return new SessionView(s.getId(), s.getCourseId(), s.getSlotId(), s.getLessonDate(), s.getOpenedAt(), s.getExpiresAt(),
                s.getClosedAt(), s.isLive(now) ? "OPEN" : "CLOSED", attendance.countActive(s.getId()),
                enrollments.countByCourseId(s.getCourseId()), pending);
    }

    static RecordView record(AcAttendance a, Person p) {
        return new RecordView(a.getId(), a.getStudentId(), p == null ? null : p.displayName(), p == null ? null : p.studentNo(),
                a.getMethod().name(), a.getMarkedAt(), a.isRevoked());
    }
}
