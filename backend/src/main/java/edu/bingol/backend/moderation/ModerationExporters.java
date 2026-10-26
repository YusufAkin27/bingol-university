package edu.bingol.backend.moderation;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK: kullanicinin kendi gonderdigi raporlar ve itirazlari (baskalarinin verisi yok). */
@Configuration
public class ModerationExporters {

    @Bean
    DataExporter moderationExporter(ReportRepository reports, ModerationAppealRepository appeals) {
        return DataExporter.of("moderation", uid -> Map.of(
                "reportsFiled", reports.findTop200ByReporterIdOrderByIdDesc(uid).stream().map(r -> Map.of(
                        "id", r.getId(), "targetType", r.getTargetType().name(), "targetId", r.getTargetId(),
                        "reason", r.getReason().name(), "status", r.getStatus().name(),
                        "createdAt", r.getCreatedAt().toString())).toList(),
                "appeals", appeals.findTop50ByUserIdOrderByIdDesc(uid).stream()
                        .map(a -> Map.<String, Object>of("id", a.getId(), "targetType", a.getTargetType().name(),
                                "targetId", a.getTargetId(), "message", a.getMessage(),
                                "status", a.getStatus().name(), "createdAt", a.getCreatedAt().toString()))
                        .toList()));
    }
}
