package edu.bingol.backend.moderation.admin;

import edu.bingol.backend.moderation.MediaPreview;
import edu.bingol.backend.moderation.ModerationStrike;
import edu.bingol.backend.moderation.ModerationTargetState;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportTargetType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Yonetici moderasyon tamamlama (P11) istek/yanit tipleri. */
public final class ModAdminDtos {

    private ModAdminDtos() {}

    /** Sayfa tabanli liste (yonetim listeleri): page 0'dan baslar. */
    public record PageResult<T>(List<T> items, int page, int size, long total, int totalPages) {
        public static <T> PageResult<T> of(List<T> items, int page, int size, long total) {
            int pages = size <= 0 ? 0 : (int) ((total + size - 1) / size);
            return new PageResult<>(items, page, size, total, pages);
        }
    }

    // --- strike ---

    public record StrikeRow(Long id, Long userId, String userName, String userEmail, Long reportId,
                            ReportTargetType targetType, Long targetId, Report.Resolution resolution, String createdAt,
                            String revokedAt, boolean active, boolean forgiven, Long forgivenBy,
                            String forgivenReason) {
        static StrikeRow of(ModerationStrike s, String name, String email) {
            return new StrikeRow(s.getId(), s.getUserId(), name, email, s.getReportId(), s.getTargetType(),
                    s.getTargetId(), s.getResolution(), s.getCreatedAt().toString(),
                    s.getRevokedAt() == null ? null : s.getRevokedAt().toString(), s.getRevokedAt() == null,
                    s.getForgivenReason() != null || s.getForgivenBy() != null, s.getForgivenBy(),
                    s.getForgivenReason());
        }
    }

    /** Kullanicinin ihlalleri: activeCount = sayilan (iptal edilmemis) ihlal sayisi. */
    public record UserStrikes(Long userId, long activeCount, List<StrikeRow> items) {}

    /** Af sonucu: remaining = kullanicinin kalan (sayilan) ihlal sayisi. */
    public record ForgiveResult(Long id, Long userId, long remaining) {}

    public record ForgiveRequest(@NotBlank @Size(min = 5, max = 300) String reason) {}

    // --- gizlenen icerik ---

    public record HiddenRow(ReportTargetType targetType, Long targetId, ModerationTargetState.HiddenBy hiddenBy,
                            String hiddenAt, boolean reversible, boolean exists, Long ownerId, String ownerName,
                            MediaPreview preview) {}

    public record RestoreRequest(@NotBlank @Size(min = 5, max = 300) String reason) {}

    public record RestoreResult(ReportTargetType targetType, Long targetId, boolean unhidden) {}

    // --- sebep sablonu ---

    public record TemplateView(Long id, String kind, String code, String textTr, String textEn, String textAr,
                               boolean active, int sortOrder, String updatedAt) {
        static TemplateView of(ModerationReasonTemplate t) {
            return new TemplateView(t.getId(), t.getKind(), t.getCode(), t.getTextTr(), t.getTextEn(), t.getTextAr(),
                    t.isActive(), t.getSortOrder(), t.getUpdatedAt().toString());
        }
    }

    public record TemplateRequest(@Pattern(regexp = "^[A-Za-z][A-Za-z0-9_]{1,31}$") String code,
                                  @NotBlank @Size(max = 300) String textTr, @Size(max = 300) String textEn,
                                  @Size(max = 300) String textAr, Boolean active, Integer sortOrder) {}

    public record TemplatePage(List<TemplateView> items, int max) {}
}
