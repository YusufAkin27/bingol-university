package edu.bingol.backend.moderation.dto;

import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.moderation.ReportTargetType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class ModerationDtos {

    private ModerationDtos() {}

    public record CreateReportRequest(@NotNull ReportTargetType targetType, @NotNull Long targetId,
                                      @NotNull ReportReason reason, @Size(max = 500) String note) {}

    public record ReportView(Long id, Long reporterId, ReportTargetType targetType, Long targetId, ReportReason reason,
                             String note, Report.Status status, Report.Resolution resolution, String createdAt) {
        public static ReportView of(Report r) {
            return new ReportView(r.getId(), r.getReporterId(), r.getTargetType(), r.getTargetId(), r.getReason(),
                    r.getNote(), r.getStatus(), r.getResolution(), r.getCreatedAt().toString());
        }
    }

    public record ReportQueue(List<ReportView> items, Long nextCursor) {}

    public record ResolveRequest(@NotNull Report.Resolution action, @Size(max = 300) String message) {}

    public record SuspendRequest(@Size(max = 300) String reason) {}

    public record Stats(long users, long activeUsers, long suspendedUsers, long openReports, long newsItems) {}
}
