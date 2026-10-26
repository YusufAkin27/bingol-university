package edu.bingol.backend.event.admission;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK: kullanicinin kendi etkinlik basvurulari (not, yanitlar, durum). Baskalarinin verisi icermez. */
@Configuration
public class AdmissionExporters {

    @Bean
    DataExporter eventApplicationExporter(EventApplicationRepository apps) {
        return DataExporter.of("eventApplications", uid -> apps.findByUserIdOrderByIdDesc(uid).stream()
                .map(a -> Map.of(
                        "eventId", a.getEventId(),
                        "status", a.getStatus().name(),
                        "note", a.getNote() == null ? "" : a.getNote(),
                        "answers", (Object) a.answers(),
                        "createdAt", a.getCreatedAt().toString(),
                        "updatedAt", a.getUpdatedAt().toString()))
                .toList());
    }
}
