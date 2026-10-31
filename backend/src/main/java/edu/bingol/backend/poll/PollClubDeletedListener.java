package edu.bingol.backend.poll;

import edu.bingol.backend.community.ClubDeletedEvent;
import java.time.Clock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Kulup silinince kulubun taslak ve acik anketleri IPTAL edilir (T-047): oylar kapanir, sonuclar korunur, acilis /
 * kapanis hatirlatma bildirimleri durur (zamanlayici sorgulari yalniz OPEN anketleri tarar). Silme commit olduktan
 * sonra, ayri islemde calisir; hata silmeyi etkilemez. Ek olarak {@link PollAccess} yayinda olmayan kulubun anketini
 * uyelere gostermez ve oylatmaz (olay kacarsa da guvenli).
 */
@Component
public class PollClubDeletedListener {

    private static final Logger log = LoggerFactory.getLogger(PollClubDeletedListener.class);

    private final PollRepository polls;
    private final Clock clock;

    public PollClubDeletedListener(PollRepository polls, Clock clock) {
        this.polls = polls;
        this.clock = clock;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onClubDeleted(ClubDeletedEvent e) {
        try {
            polls.cancelOfCommunity(e.communityId(), clock.instant());
        } catch (RuntimeException ex) {
            log.warn("Kulup anketleri iptal edilemedi (kulup {}): {}", e.communityId(), ex.toString());
        }
    }
}
