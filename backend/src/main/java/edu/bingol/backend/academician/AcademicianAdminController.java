package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.AdminAcademicianView;
import edu.bingol.backend.academician.AcademicianDtos.AttendanceMatrix;
import edu.bingol.backend.academician.AcademicianDtos.CourseView;
import edu.bingol.backend.academician.AcademicianDtos.NoticeView;
import edu.bingol.backend.academician.AcademicianDtos.ReasonRequest;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import jakarta.validation.Valid;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici: akademisyen basvurulari (onay/ret/iptal) ve akademisyen derslerinin salt okunur gorunumu. Izin: okuma
 * users.read, yazma users.write (AdminPermissionPolicy). Yazmalar AuditInterceptor ile denetlenir; e-posta, users.pii
 * olmayan profillerde maskelenir.
 */
@RestController
@RequestMapping("/api/admin/academicians")
public class AcademicianAdminController {

    private final AcademicianService academicians;
    private final CourseService courses;
    private final AttendanceReportService reports;
    private final NoticeService notices;
    private final NoticeFileService noticeFiles;

    public AcademicianAdminController(AcademicianService academicians, CourseService courses,
                                      AttendanceReportService reports, NoticeService notices,
                                      NoticeFileService noticeFiles) {
        this.academicians = academicians;
        this.courses = courses;
        this.reports = reports;
        this.notices = notices;
        this.noticeFiles = noticeFiles;
    }

    /**
     * status bos = hepsi (virgullu coklu: status=REJECTED,REVOKED); approvalMode AUTO/ADMIN; q = ad/soyad/gorunen ad (ve yalniz
     * users.pii ile e-posta) icinde arama (maskeli profilde en az 3 karakter, e-posta aranmaz); imec = onceki sayfanin son kullanici kimligi.
     */
    @GetMapping
    public CursorPage<AdminAcademicianView> list(@RequestParam(required = false) Set<Academician.Status> status,
                                                 @RequestParam(required = false) Academician.ApprovalMode approvalMode,
                                                 @RequestParam(required = false) String q,
                                                 @RequestParam(required = false) Long cursor,
                                                 @RequestParam(defaultValue = "20") int size) {
        return academicians.list(status == null || status.isEmpty() ? EnumSet.allOf(Academician.Status.class) : status,
                approvalMode, q, cursor, size);
    }

    @AuditRead
    @GetMapping("/{userId}")
    public AdminAcademicianView detail(@PathVariable Long userId) {
        return academicians.detail(userId);
    }

    @PostMapping("/{userId}/approve")
    public AdminAcademicianView approve(@PathVariable Long userId) {
        AuditContext.target("ACADEMICIAN", userId);
        return academicians.approve(CurrentUser.id(), userId);
    }

    @PostMapping("/{userId}/reject")
    public AdminAcademicianView reject(@PathVariable Long userId, @Valid @RequestBody ReasonRequest r) {
        AuditContext.target("ACADEMICIAN", userId);
        return academicians.reject(CurrentUser.id(), userId, r.reason());
    }

    @PostMapping("/{userId}/revoke")
    public AdminAcademicianView revoke(@PathVariable Long userId, @Valid @RequestBody ReasonRequest r) {
        AuditContext.target("ACADEMICIAN", userId);
        return academicians.revoke(CurrentUser.id(), userId, r.reason());
    }

    @AuditRead
    @GetMapping("/{userId}/courses")
    public List<CourseView> coursesOf(@PathVariable Long userId) {
        return courses.listForAdmin(userId);
    }

    @AuditRead
    @GetMapping("/courses/{id}")
    public CourseView course(@PathVariable Long id) {
        return courses.getForAdmin(id);
    }

    @AuditRead
    @GetMapping("/courses/{id}/attendance")
    public AttendanceMatrix attendance(@PathVariable Long id) {
        return reports.matrixForAdmin(id);
    }

    @GetMapping("/courses/{id}/notices")
    public CursorPage<NoticeView> noticeList(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                             @RequestParam(defaultValue = "20") int size) {
        courses.getForAdmin(id);
        return notices.page(id, cursor, size);
    }

    /** Denetimli okuma: duyuru dosyasi indirme (users.read). */
    @AuditRead
    @GetMapping("/notices/{noticeId}/files/{fileId}")
    public ResponseEntity<byte[]> downloadFile(@PathVariable Long noticeId, @PathVariable Long fileId) {
        return noticeFiles.downloadForAdmin(noticeId, fileId);
    }
}
