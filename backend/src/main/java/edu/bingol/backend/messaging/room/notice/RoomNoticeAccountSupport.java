package edu.bingol.backend.messaging.room.notice;

import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.profile.UserAccountDeletedEvent;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** KVKK: hesap silinince gorulme kayitlari silinir; "verilerimi indir" kullanicinin yazdigi duyurulari icerir. */
@Configuration
public class RoomNoticeAccountSupport {

    private static final Logger log = LoggerFactory.getLogger(RoomNoticeAccountSupport.class);

    private final RoomNoticeRepository notices;

    public RoomNoticeAccountSupport(RoomNoticeRepository notices) {
        this.notices = notices;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onDeleted(UserAccountDeletedEvent e) {
        try {
            notices.deleteSeenOf(e.userId());
        } catch (RuntimeException ex) {
            log.warn("Duyuru gorulme kaydi temizlenemedi: {}", ex.toString());
        }
    }

    @Bean
    DataExporter roomNoticeExporter() {
        return DataExporter.of("roomNotices", uid -> {
            List<Map<String, Object>> out = notices.authoredBy(uid, PageRequest.of(0, 500)).stream()
                    .map(n -> Map.<String, Object>of("title", n.getTitle(), "body", n.getBody(),
                            "createdAt", n.getCreatedAt().toString()))
                    .toList();
            return out;
        });
    }
}
