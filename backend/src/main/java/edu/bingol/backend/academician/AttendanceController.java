package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.MyCourseView;
import edu.bingol.backend.academician.AcademicianDtos.NoticeView;
import edu.bingol.backend.academician.AcademicianDtos.ScanRequest;
import edu.bingol.backend.academician.AcademicianDtos.ScanResult;
import edu.bingol.backend.academician.AcademicianDtos.UpcomingView;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Ogrenci uclari: QR yoklama taramasi ve "Derslerim" (kayitli dersler, duyurular, yaklasan sinav/odevler). */
@RestController
@RequestMapping("/api")
public class AttendanceController {

    private final AttendanceScanService scans;
    private final StudentCourseService myCourses;
    private final NoticeFileService noticeFiles;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public AttendanceController(AttendanceScanService scans, StudentCourseService myCourses, NoticeFileService noticeFiles,
                                RateLimiter limiter, ClientIp clientIp) {
        this.scans = scans;
        this.myCourses = myCourses;
        this.noticeFiles = noticeFiles;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    /** Kod tahminine karsi kullanici basina dakikada 10 + IP basina dakikada 3000. */
    @io.swagger.v3.oas.annotations.Operation(summary = "Yoklama QR taramasi", description = "status: MARKED | ALREADY | PENDING. PENDING = ders kayitli olmayan ogrenci gecerli kodu okuttu, istek hocaya iletildi (final sonuc, hata degil). Hatalar: 422 ATTENDANCE_CODE_INVALID (bozuk/suresi dolmus/kapali/bilinmeyen), 403 ATTENDANCE_NOT_ENROLLED (hoca tarafindan reddedilmis ya da admin/akademisyen/ust sinir), 403 ATTENDANCE_REVOKED (hoca kaydi kaldirdi), 429.")
    @PostMapping("/attendance/scan")
    public ScanResult scan(@Valid @RequestBody ScanRequest r, HttpServletRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("attendance-scan:user:" + uid, 10, Duration.ofMinutes(1));
        // IP anahtari (ClientIp.limitKey: IPv4 aynen, IPv6 /64): bir amfi ayni kampus NAT adresi arkasinda olabilir
        limiter.check("attendance-scan:ip:" + clientIp.limitKey(req), 3000, Duration.ofMinutes(1));
        return scans.scan(uid, r);
    }

    @GetMapping("/my-courses")
    public List<MyCourseView> myCourses() {
        Long uid = CurrentUser.id();
        limiter.check("my-courses:user:" + uid, 120, Duration.ofMinutes(1));
        return myCourses.myCourses(uid);
    }

    @GetMapping("/my-courses/upcoming")
    public List<UpcomingView> upcoming() {
        Long uid = CurrentUser.id();
        limiter.check("my-courses:user:" + uid, 120, Duration.ofMinutes(1));
        return myCourses.upcoming(uid);
    }

    @GetMapping("/my-courses/{courseId}/notices")
    public CursorPage<NoticeView> notices(@PathVariable Long courseId, @RequestParam(required = false) Long cursor,
                                          @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        limiter.check("my-courses:user:" + uid, 120, Duration.ofMinutes(1));
        return myCourses.notices(uid, courseId, cursor, size);
    }

    /** Duyuru dosyasi indirme: dersin KAYITLI ogrencisi; degilse 404. attachment + nosniff + no-store. */
    @GetMapping("/my-courses/{courseId}/notices/{noticeId}/files/{fileId}")
    public ResponseEntity<byte[]> downloadFile(@PathVariable Long courseId, @PathVariable Long noticeId,
                                               @PathVariable Long fileId) {
        Long uid = CurrentUser.id();
        limiter.check("my-courses-dl:user:" + uid, 120, Duration.ofMinutes(1));
        return noticeFiles.downloadForStudent(uid, courseId, noticeId, fileId);
    }
}
