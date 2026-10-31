package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * T-043: goingCount yalniz kosullu UPDATE'lerle degisir. Bayat okunmus varligin tam-varlik UPDATE'i
 * (kayitlari kapat / baslik duzenle / kapak) sayaci eski degere ezmemeli (kapasite asimi).
 */
@SpringBootTest
class UserEventGoingCountTest {

    @Autowired
    UserEventRepository repo;

    @Autowired
    PlatformTransactionManager tm;

    /** @Modifying sorgular islem ister; varlik okuma/yazma ayri islemlerde kalir (bayat varlik senaryosu). */
    private int inTx(java.util.function.IntSupplier s) {
        return new TransactionTemplate(tm).execute(st -> s.getAsInt());
    }

    private UserEvent newEvent(Integer capacity) {
        UserEvent e = new UserEvent();
        e.setTitle("Sayac testi");
        e.setStartsAt(Instant.now().plus(Duration.ofDays(1)));
        e.setEndsAt(Instant.now().plus(Duration.ofDays(1)).plus(Duration.ofHours(2)));
        e.setCreatedBy(9100L);
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setCapacity(capacity);
        return repo.saveAndFlush(e);
    }

    @Test
    void staleFullEntityUpdateDoesNotOverwriteConcurrentRsvpCounter() {
        UserEvent created = newEvent(1);
        // Organizator ekrani etkinligi okur (goingCount = 0) ...
        UserEvent stale = repo.findById(created.getId()).orElseThrow();
        assertEquals(0, stale.getGoingCount());

        // ... bu arada bir RSVP son koltugu alir (kosullu atomik UPDATE)
        assertEquals(1, inTx(() -> repo.tryIncrementGoing(created.getId())));
        assertEquals(1, repo.goingCount(created.getId()));

        // ... organizator "kayitlari kapat" der: bayat varligin tam UPDATE'i
        stale.setRegistrationClosed(true);
        stale.setTitle("Baslik duzenlendi");
        repo.saveAndFlush(stale);

        assertEquals(1, repo.goingCount(created.getId()), "tam-varlik UPDATE sayaci eski degere ezdi");
        // kapasite (1) dolu: ikinci koltuk verilmez
        assertEquals(0, inTx(() -> repo.tryIncrementGoing(created.getId())));
        UserEvent after = repo.findById(created.getId()).orElseThrow();
        assertEquals("Baslik duzenlendi", after.getTitle());
        assertEquals(true, after.isRegistrationClosed());
    }

    @Test
    void decrementStillWorksAfterEntitySave() {
        UserEvent created = newEvent(null);
        inTx(() -> repo.tryIncrementGoing(created.getId()));
        inTx(() -> repo.tryIncrementGoing(created.getId()));
        UserEvent e = repo.findById(created.getId()).orElseThrow();
        e.setLocation("Salon");
        repo.saveAndFlush(e);

        assertEquals(1, inTx(() -> repo.decrementGoing(created.getId())));
        assertEquals(1, repo.goingCount(created.getId()));
    }
}
