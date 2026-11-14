package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.PendingScanView;
import edu.bingol.backend.academician.AcademicianDtos.RecordView;
import edu.bingol.backend.academician.AcademicianDtos.ScanResult;
import edu.bingol.backend.academician.StudentDirectory.Person;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Kayitli olmayan ogrencinin GECERLI canli kodu okutmasi: istek olusur (PENDING), hoca "derse ekle ve var say" ya da
 * "yok say" der. Gecersiz/suresi dolmus kod asla istek olusturmaz (cagiran taramayi once dogrular). Admin ve akademisyen
 * hesaplari istek olusturamaz; reddedilmis ogrenci ayni oturumda tekrar taradiginda 403 ATTENDANCE_NOT_ENROLLED alir;
 * oturum basina bekleyen istek ust siniri {@code app.academician.pending-scan-cap}.
 */
@Service
public class PendingScanService {

    static final int LIST_MAX = 500;

    private final AcademicianGuard guard;
    private final AcScanRequestRepository requests;
    private final AcEnrollmentRepository enrollments;
    private final AcAttendanceRepository attendance;
    private final AcCourseRepository courses;
    private final AcademicianRepository academicians;
    private final UserRepository users;
    private final StudentDirectory directory;
    private final AcademicianNotifier notifier;
    private final AbsenceWarningService warnings;
    private final AcademicianProperties props;
    private final Clock clock;
    private final TransactionTemplate tx;

    public PendingScanService(AcademicianGuard guard, AcScanRequestRepository requests, AcEnrollmentRepository enrollments,
                              AcAttendanceRepository attendance, AcCourseRepository courses, AcademicianRepository academicians,
                              UserRepository users, StudentDirectory directory, AcademicianNotifier notifier,
                              AbsenceWarningService warnings, AcademicianProperties props, Clock clock,
                              PlatformTransactionManager tm) {
        this.guard = guard;
        this.requests = requests;
        this.enrollments = enrollments;
        this.attendance = attendance;
        this.courses = courses;
        this.academicians = academicians;
        this.users = users;
        this.directory = directory;
        this.notifier = notifier;
        this.warnings = warnings;
        this.props = props;
        this.clock = clock;
        this.tx = new TransactionTemplate(tm);
    }

    /** Tarama akisindan: kayitli olmayan ogrenci, kod/pencere/oturum kontrolleri GECTIKTEN sonra. */
    ScanResult onScan(Long studentId, AcSession s, AcCourse c, Instant now) {
        boolean barred = academicians.existsById(studentId)
                || users.findById(studentId).map(u -> u.getRole() == Role.ADMIN).orElse(true);
        if (barred) {
            throw AcErrors.notEnrolled();
        }
        ScanResult pending = new ScanResult("PENDING", c.getName(), s.getLessonDate());
        AcScanRequest existing = requests.findBySessionIdAndStudentId(s.getId(), studentId).orElse(null);
        if (existing != null) {
            switch (existing.getStatus()) {
                case PENDING -> {
                    return pending;
                }
                case DISMISSED -> throw AcErrors.notEnrolled();
                case ACCEPTED -> {
                    // kabul edilmisti ama ogrenci sonradan dersten cikarildi: yeniden hocaya sun
                    tx.executeWithoutResult(st -> {
                        existing.setStatus(AcScanRequest.Status.PENDING);
                        existing.setScannedAt(now);
                        existing.setDecidedAt(null);
                        existing.setDecidedBy(null);
                        requests.save(existing);
                    });
                    return pending;
                }
            }
        }
        if (requests.countPending(s.getId()) >= props.pendingScanCap()) {
            throw AcErrors.notEnrolled();
        }
        try {
            tx.executeWithoutResult(st -> {
                AcScanRequest r = new AcScanRequest();
                r.setSessionId(s.getId());
                r.setStudentId(studentId);
                r.setScannedAt(now);
                r.setStatus(AcScanRequest.Status.PENDING);
                requests.saveAndFlush(r);
            });
        } catch (DataIntegrityViolationException dup) {
            // es zamanli ikinci tarama: istek zaten var
        }
        return pending;
    }

    /** Bekleyen istekler (yalniz PENDING; eski -> yeni). */
    List<PendingScanView> list(Long sessionId) {
        List<AcScanRequest> rows = requests.pending(sessionId, PageRequest.of(0, LIST_MAX));
        if (rows.isEmpty()) {
            return List.of();
        }
        Map<Long, Person> people = directory.labels(rows.stream().map(AcScanRequest::getStudentId).toList());
        return rows.stream().map(r -> {
            Person p = people.get(r.getStudentId());
            return new PendingScanView(r.getStudentId(), p == null ? null : p.displayName(), p == null ? null : p.studentNo(),
                    p == null ? null : p.faculty(), p == null ? null : p.department(), p == null ? null : p.grade(),
                    r.getScannedAt());
        }).toList();
    }

    /**
     * Derse ekle + bu oturumda "var" say (yontem QR, marked_at = scanned_at); istek ACCEPTED. Oturum kapaliyken de calisir.
     * Idempotent: ogrenci arada elle eklenmisse yalnizca yoklamayi isler ve istegi kapatir; satir zaten varsa degismez.
     */
    public RecordView accept(Long userId, Long sessionId, Long studentId) {
        AcSession s = guard.ownSession(userId, sessionId);
        AcScanRequest req = requests.findBySessionIdAndStudentId(sessionId, studentId).orElseThrow(AcErrors::scanRequestNotFound);
        AcCourse c = courses.findById(s.getCourseId()).orElseThrow(AcErrors::courseNotFound);
        boolean newlyEnrolled = false;
        if (!enrollments.existsByCourseIdAndStudentId(c.getId(), studentId)) {
            if (enrollments.countByCourseId(c.getId()) >= EnrollmentService.MAX_ENROLLED) {
                throw new ApiException(HttpStatus.CONFLICT, "AC_ENROLLMENT_LIMIT",
                        "Bir derse en fazla " + EnrollmentService.MAX_ENROLLED + " öğrenci eklenebilir.",
                        String.valueOf(EnrollmentService.MAX_ENROLLED));
            }
            newlyEnrolled = insertEnrollment(c.getId(), studentId);
        }
        AcAttendance a = attendance.findBySessionIdAndStudentId(sessionId, studentId).orElse(null);
        if (a == null) {
            Instant at = req.getScannedAt();
            try {
                a = tx.execute(st -> {
                    AcAttendance n = new AcAttendance();
                    n.setSessionId(sessionId);
                    n.setStudentId(studentId);
                    n.setMethod(AcAttendance.Method.QR);
                    n.setMarkedAt(at);
                    return attendance.saveAndFlush(n);
                });
            } catch (DataIntegrityViolationException dup) {
                a = attendance.findBySessionIdAndStudentId(sessionId, studentId).orElseThrow(() -> dup);
            }
        }
        if (req.getStatus() != AcScanRequest.Status.ACCEPTED) {
            tx.executeWithoutResult(st -> {
                req.setStatus(AcScanRequest.Status.ACCEPTED);
                req.setDecidedAt(clock.instant());
                req.setDecidedBy(userId);
                requests.save(req);
            });
        }
        if (newlyEnrolled) {
            notifier.enrolled(c.getId(), c.getName(), guard.requireApproved(userId).fullName(), List.of(studentId));
        }
        warnings.recompute(c.getId(), List.of(studentId));
        return AcSessionService.record(a, directory.labels(List.of(studentId)).get(studentId));
    }

    /** "Yok say": istek DISMISSED, baska hicbir sey degismez. Zaten karara baglanmis istekte no-op (idempotent). */
    public void dismiss(Long userId, Long sessionId, Long studentId) {
        guard.ownSession(userId, sessionId);
        AcScanRequest req = requests.findBySessionIdAndStudentId(sessionId, studentId).orElseThrow(AcErrors::scanRequestNotFound);
        if (req.getStatus() == AcScanRequest.Status.PENDING) {
            tx.executeWithoutResult(st -> {
                req.setStatus(AcScanRequest.Status.DISMISSED);
                req.setDecidedAt(clock.instant());
                req.setDecidedBy(userId);
                requests.save(req);
            });
        }
    }

    private boolean insertEnrollment(Long courseId, Long studentId) {
        try {
            return Boolean.TRUE.equals(tx.execute(st -> {
                AcEnrollment e = new AcEnrollment();
                e.setCourseId(courseId);
                e.setStudentId(studentId);
                enrollments.saveAndFlush(e);
                return true;
            }));
        } catch (DataIntegrityViolationException dup) {
            return false;
        }
    }
}
