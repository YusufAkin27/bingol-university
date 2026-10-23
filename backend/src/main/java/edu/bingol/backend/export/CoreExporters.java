package edu.bingol.backend.export;

import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.notification.NotificationPref;
import edu.bingol.backend.notification.NotificationPrefRepository;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsView;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.dto.ProfileDtos.ProfileView;
import edu.bingol.backend.support.feedback.Feedback;
import edu.bingol.backend.support.feedback.FeedbackDtos.FeedbackView;
import edu.bingol.backend.support.feedback.FeedbackRepository;
import edu.bingol.backend.support.ticket.TicketDtos.TicketDetail;
import edu.bingol.backend.support.ticket.TicketRepository;
import edu.bingol.backend.support.ticket.TicketService;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Cekirdek modullerin disa aktarim bolumleri. Mesajlasma/topluluk gibi sonradan eklenen moduller kendi bean'ini ekler. */
@Configuration
public class CoreExporters {

    @Bean
    DataExporter profileExporter(ProfileService profiles) {
        return DataExporter.of("profile", uid -> ProfileView.of(profiles.get(uid)));
    }

    @Bean
    DataExporter consentExporter(LegalService legal) {
        return DataExporter.of("legalConsents", legal::mine);
    }

    @Bean
    DataExporter notificationPrefExporter(NotificationPrefRepository prefs) {
        return DataExporter.of("notificationPreferences",
                uid -> PrefsView.of(prefs.findById(uid).orElseGet(() -> NotificationPref.defaults(uid))));
    }

    @Bean
    DataExporter blockExporter(BlockService blocks) {
        return DataExporter.of("blockedUserIds", uid -> blocks.blockedBy(uid).stream().map(UserBlock::getBlockedId).toList());
    }

    @Bean
    DataExporter feedbackExporter(FeedbackRepository feedback) {
        return DataExporter.of("feedback", uid -> feedback.findByUserIdOrderByIdDesc(uid).stream()
                .map(FeedbackView::of).toList());
    }

    @Bean
    DataExporter ticketExporter(TicketRepository tickets, TicketService service) {
        return DataExporter.of("supportTickets", uid -> {
            List<TicketDetail> out = tickets.findByUserIdOrderByIdDesc(uid).stream()
                    .map(t -> service.detail(uid, t.getId())).toList();
            return Map.of("count", out.size(), "tickets", out);
        });
    }
}
