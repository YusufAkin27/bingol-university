package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.ScanRequest;
import edu.bingol.backend.academician.AcademicianDtos.ScanResult;
import java.time.Clock;
import java.time.Instant;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Ogrenci QR taramasi. Kontrol sirasi: kod cozumleme -> MAC/pencere -> oturum acik ve suresi dolmamis -> ogrenci kayitli mi ->
 * (zaten kayitli ise ALREADY) -> ekleme. Kayitli olmayan ogrenci:
 * PendingScanService (200 PENDING ya da 403 ATTENDANCE_NOT_ENROLLED). Gecersiz/suresi dolmus/kapali/bilinmeyen oturum TEK genel 422
 * (oturum varligi sizmaz). Yazma idempotenttir: es zamanli iki tarama tekil kisitla tek satira iner, hata verilmez.
 */
@Service
public class AttendanceScanService {

    private final LessonCodeService codes;
    private final AcSessionRepository sessions;
    private final AcCourseRepository courses;
    private final AcEnrollmentRepository enrollments;
    private final AcAttendanceRepository attendance;
    private final Clock clock;
    private final SessionFinalizer finalizer;
    private final PendingScanService pending;
    private final TransactionTemplate tx;

    public AttendanceScanService(LessonCodeService codes, AcSessionRepository sessions, AcCourseRepository courses,
                                 AcEnrollmentRepository enrollments, AcAttendanceRepository attendance,
                                 Clock clock, SessionFinalizer finalizer, PendingScanService pending,
                                 PlatformTransactionManager tm) {
        this.codes = codes;
        this.sessions = sessions;
        this.courses = courses;
        this.enrollments = enrollments;
        this.attendance = attendance;
        this.clock = clock;
        this.finalizer = finalizer;
        this.pending = pending;
        this.tx = new TransactionTemplate(tm);
    }

    public ScanResult scan(Long studentId, ScanRequest r) {
        return scan(studentId, r, clock.instant());
    }

    ScanResult scan(Long studentId, ScanRequest r, Instant now) {
        long sessionId = codes.verify(r.code(), now);
        if (sessionId < 0) {
            throw AcErrors.codeInvalid();
        }
        AcSession s = sessions.findById(sessionId).orElseThrow(AcErrors::codeInvalid);
        if (!s.isLive(now)) {
            finalizer.observeExpired(java.util.List.of(s), now); // suresi dolmus oturumun ilk gozlenisi: kesinlestir
            throw AcErrors.codeInvalid();
        }
        AcCourse c = courses.findById(s.getCourseId()).orElseThrow(AcErrors::codeInvalid);
        if (c.getStatus() != AcCourse.Status.ACTIVE) {
            throw AcErrors.codeInvalid();
        }
        if (!enrollments.existsByCourseIdAndStudentId(c.getId(), studentId)) {
            // gecerli kod + acik oturum gecildi: kayitli olmayan ogrenci hocaya sunulur (PENDING) ya da reddedilir
            return pending.onScan(studentId, s, c, now);
        }
        AcAttendance existing = attendance.findBySessionIdAndStudentId(sessionId, studentId).orElse(null);
        if (existing != null) {
            if (existing.isRevoked()) {
                throw AcErrors.revoked();
            }
            return new ScanResult("ALREADY", c.getName(), s.getLessonDate());
        }
        boolean inserted = tryInsert(sessionId, studentId, now);
        return new ScanResult(inserted ? "MARKED" : "ALREADY", c.getName(), s.getLessonDate());
    }

    /** Tekil kisit ihlali (es zamanli tarama) hata degil: satir zaten var. true = bu cagri ekledi. */
    boolean tryInsert(Long sessionId, Long studentId, Instant now) {
        try {
            tx.executeWithoutResult(st -> {
                AcAttendance a = new AcAttendance();
                a.setSessionId(sessionId);
                a.setStudentId(studentId);
                a.setMethod(AcAttendance.Method.QR);
                a.setMarkedAt(now);
                attendance.saveAndFlush(a);
            });
            return true;
        } catch (DataIntegrityViolationException dup) {
            return false;
        }
    }
}
