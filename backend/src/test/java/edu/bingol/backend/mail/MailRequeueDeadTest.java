package edu.bingol.backend.mail;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Yonetici "olu postalari yeniden dene" sorgusu: degiskeni temizlenmis (DEAD olurken {}) ve suresi dolmus kod
 * postalari kuyruga alinmaz (bos degiskenle bos/kodsuz posta gitmesin).
 */
@SpringBootTest
class MailRequeueDeadTest {

    @Autowired MailOutboxRepository outbox;

    private MailOutbox row(MailTemplate t, String vars, Instant created) {
        MailOutbox m = new MailOutbox();
        m.setToAddress("requeue-test@bingol.edu.tr");
        m.setTemplate(t);
        m.setLang("tr");
        m.setVarsJson(vars);
        m.setStatus(MailStatus.DEAD);
        m.setAttempts(5);
        m.setNextAttemptAt(Instant.now());
        m.setCreatedAt(created);
        return outbox.save(m);
    }

    private MailStatus status(MailOutbox m) {
        return outbox.findById(m.getId()).orElseThrow().getStatus();
    }

    @Test
    void requeuesOnlyRebuildableMails() {
        Instant now = Instant.now();
        Instant old = now.minus(Duration.ofHours(1));
        MailOutbox cleared = row(MailTemplate.ANNOUNCEMENT, "{}", old);
        MailOutbox withVars = row(MailTemplate.ANNOUNCEMENT, "{\"title\":\"x\"}", old);
        MailOutbox deleted = row(MailTemplate.ACCOUNT_DELETED, "{}", old);
        MailOutbox staleCode = row(MailTemplate.VERIFICATION_CODE, "{\"code\":\"123456\"}", old);
        MailOutbox freshCode = row(MailTemplate.PASSWORD_RESET_CODE, "{\"code\":\"123456\"}", now.minusSeconds(60));

        outbox.requeueDead(now, now.minus(Duration.ofMinutes(10)));

        assertEquals(MailStatus.DEAD, status(cleared));
        assertEquals(MailStatus.PENDING, status(withVars));
        assertEquals(MailStatus.PENDING, status(deleted));
        assertEquals(MailStatus.DEAD, status(staleCode));
        assertEquals(MailStatus.PENDING, status(freshCode));
    }
}
