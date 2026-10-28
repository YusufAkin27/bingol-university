package edu.bingol.backend.community.admin;

import edu.bingol.backend.community.Community.JoinPolicy;
import edu.bingol.backend.community.Community.Visibility;
import edu.bingol.backend.community.CommunityMember.Role;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Yonetici kulup yonetimi ve kulup icerigi moderasyonu (P06/P10) istek-yanit kayitlari. Sozlesme: docs/changes/clubadmin.md. */
public final class ClubAdminDtos {

    private ClubAdminDtos() {}

    /** Sayfa tabanli liste (yonetim listeleri): page 0'dan baslar. */
    public record PageResult<T>(List<T> items, int page, int size, long total, int totalPages) {
        public static <T> PageResult<T> of(List<T> items, int page, int size, long total) {
            int pages = size <= 0 ? 0 : (int) ((total + size - 1) / size);
            return new PageResult<>(items, page, size, total, pages);
        }
    }

    /** Liste satiri. status: PENDING_REVIEW | ACTIVE | REJECTED | HIDDEN (zorla kapali) | DELETED. */
    public record ClubRow(Long id, String name, String slug, String category, String status, String visibility,
                          String joinPolicy, Long ownerId, String ownerName, String ownerEmail, String coverUrl,
                          String logoUrl, long memberCount, long pendingCount, int openReportCount, long eventCount,
                          Instant createdAt, Instant updatedAt) {
    }

    public record StaffRow(Long userId, String displayName, String email, Role role) {
    }

    /** Durum geçmişi ve son denetim satırı (club_audit). */
    public record AuditRow(Long id, String action, Long actorId, String actorName, Long targetUserId,
                           String targetName, String detail, Instant at) {
    }

    public record ReportRow(Long id, String reason, String note, String status, Instant createdAt) {
    }

    /** Arayuzun hangi eylemleri gosterecegi (sunucu durum kurallarinin aynasi). */
    public record Capabilities(boolean canEdit, boolean canClose, boolean canReopen, boolean canDelete,
                               boolean canTransfer, boolean canApprove) {
    }

    public record ClubDetail(ClubRow club, String description, String reviewNote, List<StaffRow> staff,
                             long bannedCount, List<AuditRow> statusHistory, List<ReportRow> openReports,
                             List<AuditRow> recentAudit, Capabilities capabilities) {
    }

    public record MemberRow(Long userId, String displayName, String email, String avatarUrl, Role role, String status,
                            String accountStatus, Instant joinedAt, boolean customPermissions) {
    }

    /** Silme/kapatma/devir sonuclari: irreversible = geri alinamaz (arayuz uyarisi). */
    public record ActionResult(Long id, String status, boolean irreversible, int notified) {
    }

    public record MemberActionResult(Long communityId, Long userId, String result) {
    }

    // ---- istekler ----

    /** Alanlarin hepsi opsiyonel. Sebep istege baglidir (X-Admin-Reason basligi da kabul edilir). */
    public record UpdateRequest(@Size(min = 3, max = 80) String name, @Size(max = 1000) String description,
                                @Size(max = 40) String category, JoinPolicy joinPolicy, Visibility visibility,
                                @Size(max = 300) String reason) {
    }

    /** Sebep burada da denetim kaydi icin okunur (AdminReasonFilter govdedeki `reason` alanini zaten ayiklar). */
    public record ReasonRequest(@Size(max = 300) String reason) {
    }

    public record RoleRequest(@NotNull Role role, @Size(max = 300) String reason) {
    }

    /** keepAsAdmin bos = true: eski sahip yonetici (ADMIN) olarak kalir. */
    public record TransferRequest(@NotNull Long targetUserId, Boolean keepAsAdmin, @Size(max = 300) String reason) {
    }

    public record PostEditRequest(@NotNull @Size(min = 1, max = 2000) String text, @Size(max = 300) String reason) {
    }

    // ---- icerik (gonderi + duyuru) ----

    public record PostAuthor(Long id, String displayName, String email, String avatarUrl) {
    }

    /** kind: POST | ANNOUNCEMENT; state: VISIBLE | HIDDEN | DELETED. */
    public record PostRow(Long id, Long communityId, String communityName, String kind, String state, PostAuthor author,
                          String text, String imageUrl, boolean pinned, int openReportCount, String hiddenReason,
                          Long hiddenBy, Instant hiddenAt, Instant editedAt, Instant createdAt) {
    }

    public record PostDetail(PostRow post, List<ReportRow> reports) {
    }

    public record PostActionResult(Long id, String state, boolean irreversible) {
    }
}
