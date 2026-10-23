package edu.bingol.backend.analytics;

import edu.bingol.backend.export.DataExporter;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Saat kaynagi ve KVKK veri disa aktarimi bolumleri (kullanicinin kendi gunluk acilislari ve olaylari). */
@Configuration
public class AnalyticsConfig {

    public static final int EVENT_RETENTION_DAYS = 180;

    /** Testte sabit saatle degistirilebilsin diye bean. */
    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    DataExporter activityExporter(ActivityRepository repo) {
        return DataExporter.of("activity", uid -> Map.of("dailyOpens", repo.recentDays(uid, 400)));
    }

    @Bean
    DataExporter analyticsEventExporter(ActivityRepository repo) {
        return DataExporter.of("analyticsEvents", uid -> {
            List<ActivityRepository.EventRow> events = repo.eventsOf(uid);
            return Map.of("retentionDays", EVENT_RETENTION_DAYS, "count", events.size(), "events", events);
        });
    }
}
