package edu.bingol.backend.event.admin;

import edu.bingol.backend.event.EventAttendance.Method;
import edu.bingol.backend.event.admission.EventApplication;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/**
 * Yonetici etkinlik derin yonetimi (P07) istek/yanit kayitlari. Kisisel veri kisitli: e-posta HER ZAMAN maskeli
 * ("a***@bingol.edu.tr"); geri bildirimde yazan kimligi hicbir kosulda donmez.
 */
public final class AdminEventOpsDtos {

    private AdminEventOpsDtos() {}

    /** Sebep govdesi (opsiyonel: sebep ayrica X-Admin-Reason basligiyla da gelebilir; zorunlulugu AdminGuardInterceptor denetler). */
    public record ReasonBody(@Size(max = 300) String reason) {
    }

    // ---- basvurular ----

    /** Kapasite bilgisi: seatsLeft null = sinirsiz kapasite. */
    public record ApplicationSummary(String mode, Integer capacity, int goingCount, Integer seatsLeft, long pending,
                                     long accepted, long waitlisted, long rejected, long cancelled) {
    }

    public record AdminApplicationRow(Long id, Long userId, String displayName, String emailMasked, String department,
                                      EventApplication.Status status, String note, List<String> answers,
                                      Instant queuedAt, Long decidedBy, Instant decidedAt, String decisionNote,
                                      Instant createdAt, Instant updatedAt) {
    }

    public record AdminApplicationPage(List<AdminApplicationRow> items, Long nextCursor, ApplicationSummary summary) {
    }

    /** Karar sonucu: yeni durum + guncel kapasite ozeti. */
    public record ApplicationDecision(Long id, Long userId, EventApplication.Status status, ApplicationSummary summary) {
    }

    // ---- yoklama ----

    /** present null = kayit yok (isaretlenmemis). rsvp "GOING" | "WALK_IN" (RSVP'siz, kapidan). */
    public record AdminAttendanceRow(Long userId, String displayName, String emailMasked, String department,
                                     String rsvp, Boolean present, Method method, Long markedBy, String markedByName,
                                     Instant markedAt, boolean hasCertificate, boolean certificateRevoked) {
    }

    public record AttendanceSummary(int going, int present, int absent, int unmarked, int walkIns) {
    }

    public record AdminAttendanceView(List<AdminAttendanceRow> rows, AttendanceSummary summary, boolean truncated) {
    }

    public record AttendanceMarkRequest(@NotNull Boolean present, @Size(max = 300) String reason) {
    }

    /** certificateValid: sertifika var, iptal edilmemis ve kisi su an "geldi" isaretli (dogrulama bunu arar). */
    public record AttendanceMarkResult(Long userId, boolean present, boolean certificateExists, boolean certificateValid) {
    }

    // ---- sertifika ----

    public record AdminCertificateRow(Long id, Long userId, String holderName, String emailMasked, String codeHint,
                                      Instant issuedAt, boolean attended, boolean revoked, Instant revokedAt,
                                      Long revokedBy, String revokeReason, boolean valid) {
    }

    // ---- geri bildirim ----

    /** Yazan kimligi YOK (anonim). */
    public record AdminFeedbackRow(Long id, int rating, String comment, Instant createdAt) {
    }

    public record FeedbackStats(long total, double average, long[] distribution) {
    }

    public record AdminFeedbackPage(List<AdminFeedbackRow> items, Long nextCursor, FeedbackStats summary) {
    }

    // ---- duyuru / duzenleyen ----

    /** Duyuru metni saklanmaz; yalniz gonderim kaydi (gonderen, alici sayisi, zaman). */
    public record AdminAnnouncementRow(Long id, Long senderId, String senderName, int recipients, Instant createdAt) {
    }

    /** role: OWNER | CO_ORGANIZER. removable yalniz ortak duzenleyende true. */
    public record AdminOrganizerRow(Long userId, String displayName, String emailMasked, String role, Long addedBy,
                                    Instant createdAt, boolean removable) {
    }

    // ---- toplu islem ----

    public enum BulkAction { HIDE, UNHIDE, CANCEL }

    public record BulkRequest(@NotNull BulkAction action, @NotEmpty List<Long> ids, @Size(max = 300) String reason) {
    }

    /** ok=false ise error ApiException kodu (ornek EVENT_INVALID_TRANSITION), status HTTP kodu. */
    public record BulkItem(Long id, boolean ok, int status, String error) {
    }

    public record BulkResult(BulkAction action, int requested, int done, int failed, List<BulkItem> items) {
    }
}
