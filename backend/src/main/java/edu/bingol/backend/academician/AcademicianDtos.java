package edu.bingol.backend.academician;

import com.fasterxml.jackson.annotation.JsonInclude;
import edu.bingol.backend.academician.LessonCodeService.CodeWindow;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/** Akademisyen alani API kayitlari (docs/changes/academician.md). Entity'ler API'ye dogrudan donmez. */
public final class AcademicianDtos {

    private AcademicianDtos() {}

    // ---- kimlik / basvuru ----

    public record ApplyRequest(@NotBlank @Size(max = 40) String title, @NotBlank @Size(max = 60) String firstName,
                               @NotBlank @Size(max = 60) String lastName, @Size(max = 160) String unit) {}

    public record StatusView(String status) {}

    public record MeView(String status, String approvalMode, String title, String firstName, String lastName, String unit,
                         String rejectReason) {}

    // ---- ders ----

    public record CourseRequest(@Size(max = 30) String code, @NotBlank @Size(max = 200) String name,
                                @NotBlank @Size(max = 40) String term, @Size(max = 160) String faculty,
                                @NotBlank @Size(max = 160) String department, @Size(max = 8) String grade) {}

    /** Verilmeyen (null) alan degismez. absenceLimitType: COUNT, PERCENT ya da NONE (siniri kaldirir). */
    public record CoursePatch(@Size(max = 30) String code, @Size(max = 200) String name, @Size(max = 40) String term,
                              @Size(max = 160) String faculty, @Size(max = 160) String department,
                              @Size(max = 8) String grade, @Size(max = 8) String absenceLimitType,
                              Integer absenceLimitValue, @Size(max = 16) String status) {}

    public record SlotRequest(@Min(1) @Max(7) int dayOfWeek, @NotBlank @Size(max = 5) String startTime,
                              @NotBlank @Size(max = 5) String endTime, @Size(max = 100) String room) {}

    public record SlotView(Long id, int dayOfWeek, String startTime, String endTime, String room) {}

    public record LimitView(String type, Integer value) {}

    public record CourseView(Long id, String code, String name, String term, String faculty, String department, String grade,
                             LimitView limit, String absenceLimitType, Integer absenceLimitValue, String status,
                             List<SlotView> slots, Long enrolledCount, Long sessionCount,
                             Instant createdAt) {}

    // ---- ogrenci rehberi / kayit ----

    /** E-posta, avatar, biyografi, cevrimici durumu ASLA icermez. */
    public record StudentView(Long id, String displayName, String studentNo, String faculty, String department, String grade) {}

    public record EnrollmentView(Long studentId, String displayName, String studentNo, String faculty, String department,
                                 String grade, Instant addedAt) {}

    public record AddEnrollmentsRequest(@NotNull @Size(min = 1, max = 100) List<Long> studentIds) {}

    public record BulkEnrollRequest(@NotBlank @Size(max = 160) String department, @Size(max = 8) String grade) {}

    public record AddedResult(int added) {}

    // ---- oturum / canli ----

    public record OpenSessionRequest(LocalDate lessonDate, Long slotId,
                                     @com.fasterxml.jackson.annotation.JsonProperty("notify") Boolean notifyStudents) {}

    /** Kayitli olmayan ve hoca karari bekleyen ogrenci (yalniz PENDING). */
    public record PendingScanView(Long studentId, String displayName, String studentNo, String faculty, String department,
                                  String grade, Instant scannedAt) {}

    /** pendingScans: tek oturum yanitlarinda (acma/kapatma/yeniden acma/detay) dolu; liste ucunda null (gonderilmez). */
    public record SessionView(Long id, Long courseId, Long slotId, LocalDate lessonDate, Instant openedAt, Instant expiresAt,
                              Instant closedAt, String status, long presentCount, long enrolledCount,
                              List<PendingScanView> pendingScans) {}

    public record RecordView(Long id, Long studentId, String displayName, String studentNo, String method, Instant markedAt, boolean revoked) {}

    public record LiveView(String status, long serverNowMs, long stepSeconds, List<CodeWindow> codes, long presentCount,
                           long enrolledCount, List<RecordView> newRecords, List<PendingScanView> pendingScans) {}

    // ---- devamsizlik ----

    public record SessionRef(Long id, LocalDate lessonDate) {}

    /** marks: oturum kimligi (metin) -> PRESENT_QR | PRESENT_MANUAL | REVOKED | ABSENT. */
    public record StudentRow(Long studentId, String displayName, String studentNo, Map<String, String> marks, int absentCount,
                             boolean atRisk, boolean overLimit) {}

    public record AttendanceMatrix(List<SessionRef> sessions, List<StudentRow> students, LimitView limit) {}

    // ---- ders duyurulari ----

    /** fileIds: once /notice-files ile yuklenen bekleyen dosya kimlikleri (en cok 5; yalniz EXAM/ASSIGNMENT/MATERIAL). */
    public record NoticeRequest(@NotNull AcNotice.Type type, @Size(max = 120) String title, @Size(max = 1000) String note,
                                Instant eventAt, List<Long> fileIds) {}

    public record FileView(Long id, String name, String contentType, long sizeBytes) {}

    public record NoticeView(Long id, String type, String title, String note, Instant eventAt, Instant createdAt,
                             List<FileView> files) {}

    // ---- ogrenci tarafi ----

    public record ScanRequest(@NotBlank @Size(max = 300) String code) {}

    /** status: MARKED | ALREADY | PENDING (kayitli degil: hocaya iletildi). */
    public record ScanResult(String status, String courseName, LocalDate lessonDate) {}

    public record MyCourseView(Long courseId, String courseName, String code, String term, String academicianName,
                               long presentCount, long absentCount, long sessionCount, LimitView limit, boolean atRisk,
                               boolean overLimit) {}

    public record UpcomingView(Long id, Long courseId, String courseName, String type, String title, String note,
                               Instant eventAt, List<FileView> files) {}

    // ---- yonetici ----

    public record ReasonRequest(@NotBlank @Size(max = 300) String reason) {}

    @JsonInclude(JsonInclude.Include.ALWAYS)
    public record AdminAcademicianView(Long userId, String email, String displayName, String title, String firstName,
                                       String lastName, String unit, String status, String approvalMode,
                                       String rejectReason, Long reviewedBy, Instant reviewedAt, Instant createdAt) {}
}
