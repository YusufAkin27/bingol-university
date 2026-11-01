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
import edu.bingol.backend.support.ticket.TicketService;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

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

    /** Diger bolumlerle ayni ust sinir ({@link ExtraExporters#MAX_ROWS}); FIX-P08 (A07#16): sinirsiz liste yok. */
    static final int PAGE = 500;

    @Bean
    DataExporter feedbackExporter(FeedbackRepository feedback, JdbcTemplate jdbc) {
        return DataExporter.of("feedback", uid -> {
            List<Long> ids = latestIds(jdbc, "feedback", "user_id", uid);
            List<Feedback> rows = new ArrayList<>(ids.size());
            for (int i = 0; i < ids.size(); i += PAGE) {
                rows.addAll(feedback.findAllById(ids.subList(i, Math.min(i + PAGE, ids.size()))));
            }
            rows.sort(Comparator.comparing(Feedback::getId).reversed());
            return rows.stream().map(FeedbackView::of).toList();
        });
    }

    @Bean
    DataExporter ticketExporter(TicketService service, JdbcTemplate jdbc) {
        return DataExporter.of("supportTickets", uid -> {
            List<TicketDetail> out = latestIds(jdbc, "support_ticket", "user_id", uid).stream()
                    .map(id -> service.detail(uid, id)).toList();
            return Map.of("count", out.size(), "tickets", out);
        });
    }

    /** Kullanicinin en yeni {@link ExtraExporters#MAX_ROWS} kaydinin kimlikleri (yeniden eskiye); tablo/sutun sabittir. */
    static List<Long> latestIds(JdbcTemplate jdbc, String table, String userColumn, Long uid) {
        return jdbc.queryForList("SELECT id FROM " + table + " WHERE " + userColumn + " = ? ORDER BY id DESC LIMIT "
                + ExtraExporters.MAX_ROWS, Long.class, uid);
    }
}
