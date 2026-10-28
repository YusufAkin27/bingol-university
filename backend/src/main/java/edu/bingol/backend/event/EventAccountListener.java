package edu.bingol.backend.event;

import edu.bingol.backend.event.admission.EventAdmissionHooks;
import edu.bingol.backend.profile.UserAccountDeletedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Hesap silinince etkinlik tarafi toparlanir: (1) kullanicinin kulube bagli olmayan bitmemis etkinlikleri iptal edilir
 * (yonetecek kimse kalmaz), (2) acik basvurulari kapatilir ve serbest kalan koltuklarda bekleme listesi terfi eder.
 * Commit sonrasi ayri transaction'da calisir; hata silme islemini etkilemez.
 */
@Component
public class EventAccountListener {

    private static final Logger log = LoggerFactory.getLogger(EventAccountListener.class);

    private final EventService events;
    private EventAdmissionHooks admission;

    public EventAccountListener(EventService events) {
        this.events = events;
    }

    @Autowired(required = false)
    void setAdmission(@Lazy EventAdmissionHooks admission) {
        this.admission = admission;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void onAccountDeleted(UserAccountDeletedEvent ev) {
        try {
            events.cancelForDeletedOrganizer(ev.userId());
        } catch (RuntimeException e) {
            log.warn("Silinen organizatorun etkinlikleri iptal edilemedi (kullanici {}): {}", ev.userId(), e.toString());
        }
        try {
            if (admission != null) {
                admission.onUserDeleted(ev.userId(), ev.freedEventIds());
            }
        } catch (RuntimeException e) {
            log.warn("Silinen kullanicinin basvurulari kapatilamadi (kullanici {}): {}", ev.userId(), e.toString());
        }
    }
}
