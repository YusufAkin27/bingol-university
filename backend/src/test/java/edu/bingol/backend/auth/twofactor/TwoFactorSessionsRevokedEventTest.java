package edu.bingol.backend.auth.twofactor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import edu.bingol.backend.common.AfterCommit;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Gercek Spring baglami: tum oturumlar iptal edilince (SessionsRevokedEvent, client == null) guvenilen 2FA cihazlari silinir;
 * olay islemin COMMIT sonrasi geri cagirisindan (askiya alma, sifre degisimi: AfterCommit) yayinlansa da calisir
 * ('No active transaction for update or delete query' ile dusmemeli). Yalniz bir istemciyi kapatan olay dokunmaz.
 */
@SpringBootTest
class TwoFactorSessionsRevokedEventTest {

    @Autowired TwoFactorDeviceRepository devices;
    @Autowired ApplicationEventPublisher events;
    @Autowired PlatformTransactionManager txm;
    @Autowired edu.bingol.backend.user.UserRepository users;

    private long newUser() {
        edu.bingol.backend.user.User u = new edu.bingol.backend.user.User();
        u.setEmail("tfev" + System.nanoTime() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Olay");
        u.setEmailVerified(true);
        return users.saveAndFlush(u).getId();
    }

    private void device(long uid, int n) {
        TwoFactorDevice d = new TwoFactorDevice();
        d.setUserId(uid);
        d.setDeviceHash(String.format("%064d", n));
        d.setLabel("ANDROID 2.0.5");
        d.setCreatedAt(Instant.now());
        d.setLastUsedAt(Instant.now());
        devices.save(d);
    }

    @Test
    void devicesAreDeletedWhenTheEventIsPublishedFromAfterCommit() {
        long uid = newUser();
        device(uid, 1);
        device(uid, 2);

        new TransactionTemplate(txm).executeWithoutResult(
                s -> AfterCommit.run(() -> events.publishEvent(new SessionsRevokedEvent(uid))));

        assertTrue(devices.findByUserIdOrderByLastUsedAtDesc(uid).isEmpty(), "AfterCommit olayinda cihazlar silinmedi");
    }

    @Test
    void devicesAreDeletedWhenTheEventIsPublishedInsideATransactionAndOnlyAllSessionsEventsDoIt() {
        long uid = newUser();
        device(uid, 3);

        // yalniz mobil istemcinin tek cihaz kurali olayi: cihazlara dokunmaz
        new TransactionTemplate(txm).executeWithoutResult(
                s -> events.publishEvent(new SessionsRevokedEvent(uid, "mobile", true, true)));
        assertEquals(1, devices.findByUserIdOrderByLastUsedAtDesc(uid).size());

        // tum oturumlar: islem icinden yayinlansa da (kendi satirlarina dokunmamis cagiran) silinir
        new TransactionTemplate(txm).executeWithoutResult(s -> events.publishEvent(new SessionsRevokedEvent(uid)));
        assertTrue(devices.findByUserIdOrderByLastUsedAtDesc(uid).isEmpty());
    }
}
