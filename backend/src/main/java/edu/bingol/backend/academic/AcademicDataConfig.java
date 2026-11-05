package edu.bingol.backend.academic;

import edu.bingol.backend.export.DataExporter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK: kisisel ders programi/sinav verisi disa aktarimi ("timetable" bolumu). */
@Configuration
public class AcademicDataConfig {

    @Bean
    DataExporter timetableExporter(TimetableService timetable) {
        return DataExporter.of("timetable", timetable::exportData);
    }
}
