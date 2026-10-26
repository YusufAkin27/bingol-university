package edu.bingol.backend.event.extras;

import edu.bingol.backend.export.DataExporter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK: kullanicinin kendi ortak organizator uyelikleri, geri bildirimleri, sertifikalari ve duyuru sayisi. */
@Configuration
public class ExtrasExporters {

    @Bean
    DataExporter eventExtrasExporter(CoOrganizerRepository coOrganizers, EventFeedbackRepository feedback,
                                     EventCertificateRepository certificates, EventAnnouncementRepository announcements) {
        return DataExporter.of("eventExtras", uid -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("coOrganizerOfEventIds", coOrganizers.findByUserId(uid).stream().map(CoOrganizer::getEventId).toList());
            m.put("feedback", feedback.findByUserId(uid).stream().map(f -> {
                Map<String, Object> x = new LinkedHashMap<>();
                x.put("eventId", f.getEventId());
                x.put("rating", f.getRating());
                x.put("comment", f.getComment() == null ? "" : f.getComment());
                x.put("createdAt", f.getCreatedAt().toString());
                return x;
            }).toList());
            m.put("certificates", certificates.findByUserId(uid).stream().map(c -> {
                Map<String, Object> x = new LinkedHashMap<>();
                x.put("eventId", c.getEventId());
                x.put("code", c.getCode());
                x.put("holderName", c.getHolderName());
                x.put("issuedAt", c.getIssuedAt().toString());
                return x;
            }).toList());
            m.put("announcementsSent", (List<?>) announcements.findBySenderId(uid).stream().map(a -> {
                Map<String, Object> x = new LinkedHashMap<>();
                x.put("eventId", a.getEventId());
                x.put("recipients", a.getRecipients());
                x.put("createdAt", a.getCreatedAt().toString());
                return x;
            }).toList());
            return m;
        });
    }
}
