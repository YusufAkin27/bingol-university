package edu.bingol.backend.moderation.dto;

import edu.bingol.backend.moderation.BlockedContentHash;
import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ModerationAppeal;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.moderation.ReportService.Enrichment;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.SuspendRecommendation;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;

public final class ModerationDtos {

    private ModerationDtos() {}

    public record CreateReportRequest(@NotNull ReportTargetType targetType, @NotNull Long targetId,
                                      @NotNull ReportReason reason, @Size(max = 500) String note) {}

    /**
     * Kuyruk satiri. Eski alanlar korunur; yenileri sonda: priority, reasonCode, preview (varsa), hidden/hiddenBy
     * (AUTO|ADMIN), openReporters (hedefe acik farkli raporlayici sayisi).
     */
    public record ReportView(Long id, Long reporterId, ReportTargetType targetType, Long targetId, ReportReason reason,
                             String note, Report.Status status, Report.Resolution resolution, String createdAt,
                             int priority, String reasonCode, MediaPreview preview, boolean hidden, String hiddenBy,
                             long openReporters) {
        public static ReportView of(Report r) {
            return of(r, null);
        }

        public static ReportView of(Report r, Enrichment e) {
            return new ReportView(r.getId(), r.getReporterId(), r.getTargetType(), r.getTargetId(), r.getReason(),
                    r.getNote(), r.getStatus(), r.getResolution(), r.getCreatedAt().toString(), r.getPriority(),
                    r.getReasonCode(), e == null ? null : e.preview(), e != null && e.hidden(),
                    e == null ? null : e.hiddenBy(), e == null ? 0 : e.openReporters());
        }
    }

    public record ReportQueue(List<ReportView> items, Long nextCursor) {}

    public record ResolveRequest(@NotNull Report.Resolution action, @Size(max = 300) String message,
                                 @Size(max = 32) String reasonCode) {}

    public record BulkResolveRequest(@NotEmpty @Size(max = 100) List<Long> ids, @NotNull Report.Resolution action,
                                     @Size(max = 300) String message, @Size(max = 32) String reasonCode) {}

    public record BulkResult(Long id, boolean ok, String error) {}

    public record ReasonTemplate(String code, String text, Map<String, String> texts) {}

    public record SuspendRequest(@Size(max = 300) String reason) {}

    public record Stats(long users, long activeUsers, long suspendedUsers, long openReports, long newsItems) {}

    // --- itiraz ---
    public record AppealRequest(@NotNull ReportTargetType targetType, @NotNull Long targetId,
                                @NotBlank @Size(min = 5, max = 1000) String message) {}

    public record AppealView(Long id, Long userId, ReportTargetType targetType, Long targetId, String message,
                             ModerationAppeal.Status status, String adminNote, String createdAt, String decidedAt) {
        public static AppealView of(ModerationAppeal a) {
            return new AppealView(a.getId(), a.getUserId(), a.getTargetType(), a.getTargetId(), a.getMessage(),
                    a.getStatus(), a.getAdminNote(), a.getCreatedAt().toString(),
                    a.getDecidedAt() == null ? null : a.getDecidedAt().toString());
        }
    }

    public record AppealPage(List<AppealView> items, Long nextCursor) {}

    public record AppealDecision(@NotNull Boolean accept, @Size(max = 500) String note) {}

    // --- tekrarlayan ihlal onerisi ---
    public record RecommendationView(Long id, Long userId, int strikeCount, SuspendRecommendation.Status status,
                                     String createdAt) {
        public static RecommendationView of(SuspendRecommendation s) {
            return new RecommendationView(s.getId(), s.getUserId(), s.getStrikeCount(), s.getStatus(),
                    s.getCreatedAt().toString());
        }
    }

    public record RecommendationPage(List<RecommendationView> items, Long nextCursor) {}

    // --- yasakli ozet listesi ---
    public record BlocklistAdd(@NotBlank @Size(max = 64) String sha256, @Size(max = 300) String note) {}

    public record BlocklistView(String sha256, String note, Long createdBy, String createdAt) {
        public static BlocklistView of(BlockedContentHash h) {
            return new BlocklistView(h.getSha256(), h.getNote(), h.getCreatedBy(), h.getCreatedAt().toString());
        }
    }

    public record BlocklistPage(List<BlocklistView> items, String nextCursor) {}
}
