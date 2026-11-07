package edu.bingol.backend.notification.live;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/** KVKK disa aktarim: kullanicinin canli etkinlik kayitlari (cihaz jetonu verilmez, yalniz var/yok). */
@Configuration
class LiveActivityExporters {

    @Bean
    DataExporter liveActivitiesExporter(JdbcTemplate jdbc) {
        return DataExporter.of("liveActivities", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList(
                    "SELECT kind, ref_id AS \"refId\", created_at AS \"startedAt\", ended_at AS \"endedAt\", "
                            + "(push_token IS NOT NULL) AS \"hasToken\" FROM live_activity WHERE user_id = ? "
                            + "ORDER BY id DESC LIMIT 100", uid);
            return rows;
        });
    }
}
