package edu.bingol.backend.crash;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Cokme raporu sekilleri. Sozlesme: docs/ADMIN_API.md "Cokme raporlari (CR1)". */
public final class CrashDtos {

    private CrashDtos() {
    }

    /** Mobilden gelen anonim rapor; kisisel veri alani YOKTUR (kullanici kimligi alinmaz). */
    public record ReportRequest(
            @NotBlank @Size(max = 32) @Pattern(regexp = "[A-Za-z0-9._+\\-]+") String appVersion,
            @NotBlank @Size(max = 12) String platform,
            @Size(max = 64) String osVersion,
            @Size(max = 64) String deviceModel,
            @NotBlank @Size(max = 160) String errorType,
            @Size(max = 600) String message,
            @NotBlank @Size(max = 12000) String stackTrace,
            @Size(max = 80) String screen,
            Boolean fatal,
            Instant occurredAt) {
    }

    public record VersionCount(String version, String platform, long count) {
    }

    public record GroupRow(long id, String errorType, String message, String topFrame, String status,
                           long eventCount, Instant firstSeenAt, Instant lastSeenAt, String firstVersion,
                           String lastVersion, int reopenCount, String statusReason, String statusBy,
                           Instant statusAt, String fixedInVersion, List<VersionCount> versions) {
        GroupRow withVersions(List<VersionCount> v) {
            return new GroupRow(id, errorType, message, topFrame, status, eventCount, firstSeenAt, lastSeenAt,
                    firstVersion, lastVersion, reopenCount, statusReason, statusBy, statusAt, fixedInVersion, v);
        }
    }

    public record EventRow(long id, String appVersion, String platform, String osVersion, String deviceModel,
                           String screen, boolean fatal, String message, String stack, Instant occurredAt,
                           Instant receivedAt) {
    }

    public record GroupDetail(GroupRow group, List<EventRow> events) {
    }

    public record Summary(long newGroups, long ackGroups, long resolvedGroups, long events24h, long reopened) {
    }

    public record StatusRequest(@NotBlank String status,
                                @Size(max = 300) String reason,
                                @Size(max = 32) @Pattern(regexp = "[A-Za-z0-9._+\\-]*") String fixedInVersion) {
    }
}
