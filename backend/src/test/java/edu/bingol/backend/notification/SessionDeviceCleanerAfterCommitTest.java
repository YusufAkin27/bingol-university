package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import edu.bingol.backend.common.AfterCommit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * PGVERIFY: oturum iptal olayi {@code AfterCommit} icinden (askiya alma, sifre degisimi) yayinlaninca cihaz kayitlari
 * yine silinmeli. Eskiden 'No active transaction for update or delete query' ile sessizce dusuyordu.
 */
@SpringBootTest
class SessionDeviceCleanerAfterCommitTest {

    @Autowired DeviceRepository devices;
    @Autowired ApplicationEventPublisher events;
    @Autowired PlatformTransactionManager txm;

    @Test
    void devicesAreDeletedWhenEventIsPublishedFromAfterCommit() {
        long uid = 900_000_000L + (long) (Math.random() * 1_000_000);
        Device d = new Device();
        d.setUserId(uid);
        d.setFcmToken("tok-" + UUID.randomUUID());
        d.setPlatform("ANDROID");
        devices.saveAndFlush(d);

        new TransactionTemplate(txm).executeWithoutResult(
                s -> AfterCommit.run(() -> events.publishEvent(new SessionsRevokedEvent(uid))));

        assertTrue(devices.findByUserId(uid).isEmpty(), "cihaz kaydi AfterCommit olayinda silinmedi");
    }
}
