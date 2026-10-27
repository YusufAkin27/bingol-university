package edu.bingol.backend.academic;

import edu.bingol.backend.export.DataExporter;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/** KVKK: kisisel ders programi/sinav verisi disa aktarimi ("timetable" bolumu). */
@Configuration
public class AcademicDataConfig {

    @Bean
    DataExporter timetableExporter(TimetableService timetable, JdbcTemplate jdbc) {
        return DataExporter.of("timetable", uid -> {
            Map<String, Object> out = new LinkedHashMap<>(timetable.exportData(uid));
            out.put("readAnnouncementIds", jdbc.queryForList(
                    "SELECT announcement_id FROM announcement_read WHERE user_id = ? ORDER BY announcement_id", Long.class, uid));
            return out;
        });
    }
}
