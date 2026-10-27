package edu.bingol.backend.event;

import edu.bingol.backend.community.ClubDeletedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Kulup silinince bitmemis etkinlikleri iptal eder (katilimcilara bildirim, etkinlik sohbet odalari kapanir).
 * Silme islemi commit olduktan sonra, ayri transaction'da calisir; hata silme islemini etkilemez.
 */
@Component
public class EventClubDeletedListener {

    private static final Logger log = LoggerFactory.getLogger(EventClubDeletedListener.class);

    private final EventService events;

    public EventClubDeletedListener(EventService events) {
        this.events = events;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onClubDeleted(ClubDeletedEvent e) {
        try {
            events.cancelForDeletedClub(e.communityId());
        } catch (RuntimeException ex) {
            log.warn("Kulup etkinlikleri iptal edilemedi (kulup {}): {}", e.communityId(), ex.toString());
        }
    }
}
