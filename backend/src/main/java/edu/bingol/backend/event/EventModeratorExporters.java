package edu.bingol.backend.event;

import edu.bingol.backend.export.DataExporter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK: kullanicinin etkinlik moderatorlukleri. */
@Configuration
public class EventModeratorExporters {

    @Bean
    DataExporter eventModeratorExporter(EventModeratorService svc) {
        return DataExporter.of("eventModerator", svc::exportFor);
    }
}
