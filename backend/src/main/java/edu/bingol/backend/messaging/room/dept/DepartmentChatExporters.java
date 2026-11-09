package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK disa aktarim: kullanicinin kendi ciktigi (otomatik katilimdan muaf tuttugu) bolum kanallari. */
@Configuration
class DepartmentChatExporters {

    @Bean
    DataExporter departmentChatOptoutsExporter(DepartmentChatOptoutRepository optouts) {
        return DataExporter.of("departmentChatOptouts", uid -> {
            List<Map<String, Object>> items = optouts.findByUserId(uid).stream().map(o -> {
                Map<String, Object> m = new java.util.LinkedHashMap<>();
                m.put("departmentKey", o.getDeptKey());
                m.put("leftAt", o.getCreatedAt().toString());
                return m;
            }).toList();
            return Map.of("count", items.size(), "items", items);
        });
    }
}
