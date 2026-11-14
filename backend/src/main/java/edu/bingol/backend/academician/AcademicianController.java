package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.AddEnrollmentsRequest;
import edu.bingol.backend.academician.AcademicianDtos.AddedResult;
import edu.bingol.backend.academician.AcademicianDtos.ApplyRequest;
import edu.bingol.backend.academician.AcademicianDtos.AttendanceMatrix;
import edu.bingol.backend.academician.AcademicianDtos.BulkEnrollRequest;
import edu.bingol.backend.academician.AcademicianDtos.CoursePatch;
import edu.bingol.backend.academician.AcademicianDtos.CourseRequest;
import edu.bingol.backend.academician.AcademicianDtos.CourseView;
import edu.bingol.backend.academician.AcademicianDtos.EnrollmentView;
import edu.bingol.backend.academician.AcademicianDtos.FileView;
import edu.bingol.backend.academician.AcademicianDtos.LiveView;
import edu.bingol.backend.academician.AcademicianDtos.MeView;
import edu.bingol.backend.academician.AcademicianDtos.NoticeRequest;
import edu.bingol.backend.academician.AcademicianDtos.NoticeView;
import edu.bingol.backend.academician.AcademicianDtos.OpenSessionRequest;
import edu.bingol.backend.academician.AcademicianDtos.RecordView;
import edu.bingol.backend.academician.AcademicianDtos.SessionView;
import edu.bingol.backend.academician.AcademicianDtos.SlotRequest;
import edu.bingol.backend.academician.AcademicianDtos.SlotView;
import edu.bingol.backend.academician.AcademicianDtos.StatusView;
import edu.bingol.backend.academician.AcademicianDtos.StudentView;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import jakarta.validation.Valid;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Akademisyen paneli uclari (/api/academician). Yalniz HTTP eslemesi + hiz siniri; kural servislerde. Onay kontrolu
 * AcademicianGuard'da (me ve apply haric hepsi onayli ister; baskasinin ders/oturumu 404).
 */
@RestController
@RequestMapping("/api/academician")
public class AcademicianController {

    private final AcademicianService academicians;
    private final CourseService courses;
    private final EnrollmentService enrollments;
    private final AcSessionService sessions;
    private final AttendanceReportService reports;
    private final NoticeService notices;
    private final PendingScanService pending;
    private final NoticeFileService noticeFiles;
    private final RateLimiter limiter;

    public AcademicianController(AcademicianService academicians, CourseService courses, EnrollmentService enrollments,
                                 AcSessionService sessions, AttendanceReportService reports, NoticeService notices,
                                 PendingScanService pending, NoticeFileService noticeFiles, RateLimiter limiter) {
        this.academicians = academicians;
        this.courses = courses;
        this.enrollments = enrollments;
        this.sessions = sessions;
        this.reports = reports;
        this.notices = notices;
        this.pending = pending;
        this.noticeFiles = noticeFiles;
        this.limiter = limiter;
    }

    // ---- kimlik ----

    @GetMapping("/me")
    public MeView me() {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return academicians.me(uid);
    }

    @PostMapping("/apply")
    public StatusView apply(@Valid @RequestBody ApplyRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("acad-apply:user:" + uid, 10, Duration.ofHours(1));
        return academicians.apply(uid, r);
    }

    @PutMapping("/me")
    public MeView updateMe(@Valid @RequestBody ApplyRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return academicians.updateProfile(uid, r);
    }

    // ---- dersler ----

    @GetMapping("/courses")
    public List<CourseView> courses() {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return courses.list(uid);
    }

    @PostMapping("/courses")
    @ResponseStatus(HttpStatus.CREATED)
    public CourseView createCourse(@Valid @RequestBody CourseRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return courses.create(uid, r);
    }

    @GetMapping("/courses/{id}")
    public CourseView course(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return courses.get(uid, id);
    }

    @PatchMapping("/courses/{id}")
    public CourseView patchCourse(@PathVariable Long id, @Valid @RequestBody CoursePatch p) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return courses.patch(uid, id, p);
    }

    @DeleteMapping("/courses/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCourse(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        courses.delete(uid, id);
    }

    @PutMapping("/courses/{id}/slots")
    public List<SlotView> slots(@PathVariable Long id, @Valid @RequestBody List<@Valid SlotRequest> body) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return courses.replaceSlots(uid, id, body);
    }

    // ---- ogrenci rehberi / kayit ----

    @GetMapping("/students")
    public CursorPage<StudentView> students(@RequestParam(required = false) String q,
                                            @RequestParam(required = false) String faculty,
                                            @RequestParam(required = false) String department,
                                            @RequestParam(required = false) String grade,
                                            @RequestParam(required = false) Long cursor,
                                            @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        // kullanici dizinini toplu taramayi pahalilastirir: dakikada 60 + gunluk kota (kullanici aramasiyla ayni sayilar)
        limiter.check("acad-student-search:user:" + uid, 60, Duration.ofMinutes(1));
        limiter.check("acad-student-search-day:user:" + uid, 500, Duration.ofDays(1));
        return enrollments.searchStudents(uid, q, faculty, department, grade, cursor, size);
    }

    @GetMapping("/courses/{id}/enrollments")
    public List<EnrollmentView> enrollmentList(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return enrollments.list(uid, id);
    }

    @PostMapping("/courses/{id}/enrollments")
    public AddedResult enroll(@PathVariable Long id, @Valid @RequestBody AddEnrollmentsRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return enrollments.add(uid, id, r.studentIds());
    }

    @PostMapping("/courses/{id}/enrollments/bulk")
    public AddedResult enrollBulk(@PathVariable Long id, @Valid @RequestBody BulkEnrollRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return enrollments.bulk(uid, id, r.department(), r.grade());
    }

    @DeleteMapping("/courses/{id}/enrollments/{studentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unenroll(@PathVariable Long id, @PathVariable Long studentId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        enrollments.remove(uid, id, studentId);
    }

    // ---- yoklama oturumlari ----

    @PostMapping("/courses/{id}/sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public SessionView openSession(@PathVariable Long id, @RequestBody(required = false) OpenSessionRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return sessions.open(uid, id, r);
    }

    @GetMapping("/courses/{id}/sessions")
    public List<SessionView> sessionList(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return sessions.list(uid, id);
    }

    @GetMapping("/sessions/{id}")
    public SessionView session(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return sessions.get(uid, id);
    }

    /** Web ekrani 2.5 sn'de bir yoklar (dakikada ~24); 240/dk ust sinir. */
    @GetMapping("/sessions/{id}/live")
    public LiveView live(@PathVariable Long id, @RequestParam(required = false) Long after) {
        Long uid = CurrentUser.id();
        limiter.check("acad-live:user:" + uid, 240, Duration.ofMinutes(1));
        return sessions.live(uid, id, after);
    }

    @PostMapping("/sessions/{id}/close")
    public SessionView close(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return sessions.close(uid, id);
    }

    @PostMapping("/sessions/{id}/reopen")
    public SessionView reopen(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 60, Duration.ofMinutes(1));
        return sessions.reopen(uid, id);
    }

    /** Kayitli olmayan ogrenciyi derse ekler ve bu oturumda "var" sayar (QR, marked_at = scanned_at). Idempotent. */
    @PostMapping("/sessions/{id}/pending/{studentId}/accept")
    public RecordView acceptPending(@PathVariable Long id, @PathVariable Long studentId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 120, Duration.ofMinutes(1));
        return pending.accept(uid, id, studentId);
    }

    /** "Yok say": istek reddedilir; ogrenci ayni oturumda tekrar tarayinca 403 ATTENDANCE_NOT_ENROLLED alir. Idempotent. */
    @PostMapping("/sessions/{id}/pending/{studentId}/dismiss")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void dismissPending(@PathVariable Long id, @PathVariable Long studentId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 120, Duration.ofMinutes(1));
        pending.dismiss(uid, id, studentId);
    }

    @PutMapping("/sessions/{id}/records/{studentId}")
    public RecordView mark(@PathVariable Long id, @PathVariable Long studentId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 120, Duration.ofMinutes(1));
        return sessions.mark(uid, id, studentId);
    }

    @DeleteMapping("/sessions/{id}/records/{studentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unmark(@PathVariable Long id, @PathVariable Long studentId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-write:user:" + uid, 120, Duration.ofMinutes(1));
        sessions.unmark(uid, id, studentId);
    }

    // ---- devamsizlik ----

    @GetMapping("/courses/{id}/attendance")
    public AttendanceMatrix attendance(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return reports.matrix(uid, id);
    }

    /** UTF-8 BOM'lu, CRLF, formul-enjeksiyonuna karsi kacirilmis CSV (admin/Csv). */
    @GetMapping("/courses/{id}/attendance.csv")
    public ResponseEntity<byte[]> attendanceCsv(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("acad-csv:user:" + uid, 20, Duration.ofMinutes(1));
        byte[] body = reports.csv(uid, id).getBytes(StandardCharsets.UTF_8);
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_TYPE, "text/csv; charset=UTF-8")
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"devamsizlik-" + id + ".csv\"")
                .header(HttpHeaders.CACHE_CONTROL, "no-store").body(body);
    }

    // ---- ders duyurulari ----

    @PostMapping("/courses/{id}/notices")
    @ResponseStatus(HttpStatus.CREATED)
    public NoticeView sendNotice(@PathVariable Long id, @Valid @RequestBody NoticeRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("acad-notice:user:" + uid, 60, Duration.ofMinutes(1));
        return notices.send(uid, id, r);
    }

    @GetMapping("/courses/{id}/notices")
    public CursorPage<NoticeView> noticeList(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                             @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        limiter.check("acad-read:user:" + uid, 120, Duration.ofMinutes(1));
        return notices.list(uid, id, cursor, size);
    }

    /**
     * Duyuru dosyasi yukler (multipart/form-data, tek parca "file"; her cagri TEK dosya). Donen id, duyuru olusturulurken
     * NoticeRequest.fileIds ile baglanir. 30/dk. Bekleyen dosya 24 saat icinde baglanmazsa silinir.
     */
    @PostMapping(value = "/courses/{id}/notice-files", consumes = "multipart/form-data")
    @ResponseStatus(HttpStatus.CREATED)
    public FileView uploadNoticeFile(@PathVariable Long id, @RequestPart("file") MultipartFile file) {
        Long uid = CurrentUser.id();
        limiter.check("acad-upload:user:" + uid, 30, Duration.ofMinutes(1));
        return noticeFiles.upload(uid, id, file);
    }

    /** Henuz bir duyuruya baglanmamis kendi yuklemesini siler. */
    @DeleteMapping("/notice-files/{fileId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePendingFile(@PathVariable Long fileId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-upload:user:" + uid, 30, Duration.ofMinutes(1));
        noticeFiles.deletePending(uid, fileId);
    }

    /** Indirme: attachment + nosniff + no-store; yalniz sahibi ogretim elemani (baskasi 404). */
    @GetMapping("/notices/{noticeId}/files/{fileId}")
    public ResponseEntity<byte[]> downloadNoticeFile(@PathVariable Long noticeId, @PathVariable Long fileId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-download:user:" + uid, 120, Duration.ofMinutes(1));
        return noticeFiles.downloadForOwner(uid, noticeId, fileId);
    }

    @DeleteMapping("/notices/{noticeId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteNotice(@PathVariable Long noticeId) {
        Long uid = CurrentUser.id();
        limiter.check("acad-notice:user:" + uid, 60, Duration.ofMinutes(1));
        notices.delete(uid, noticeId);
    }
}
