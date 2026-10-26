package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class MailOutboxTest {

    private static final Instant NOW = Instant.parse("2026-01-01T10:00:00Z");

    private static MailOutbox mail() {
        MailOutbox m = new MailOutbox();
        m.setVarsJson("{\"code\":\"123456\"}");
        return m;
    }

    @Test
    void backoffFollowsScheduleAndClampsAtLastStep() {
        assertThat(MailBackoff.delay(1)).isEqualTo(Duration.ofMinutes(1));
        assertThat(MailBackoff.delay(2)).isEqualTo(Duration.ofMinutes(5));
        assertThat(MailBackoff.delay(3)).isEqualTo(Duration.ofMinutes(30));
        assertThat(MailBackoff.delay(4)).isEqualTo(Duration.ofHours(2));
        assertThat(MailBackoff.delay(5)).isEqualTo(Duration.ofHours(12));
        assertThat(MailBackoff.delay(9)).isEqualTo(Duration.ofHours(12));
    }

    @Test
    void failureSchedulesRetryWithBackoff() {
        MailOutbox m = mail();

        m.markFailed("smtp down", NOW, 5);

        assertThat(m.getStatus()).isEqualTo(MailStatus.FAILED);
        assertThat(m.getAttempts()).isEqualTo(1);
        assertThat(m.getNextAttemptAt()).isEqualTo(NOW.plus(Duration.ofMinutes(1)));
        assertThat(m.getVarsJson()).contains("123456");
    }

    @Test
    void becomesDeadAfterMaxAttemptsAndScrubsVars() {
        MailOutbox m = mail();

        for (int i = 0; i < 5; i++) {
            m.markFailed("smtp down", NOW, 5);
        }

        assertThat(m.getStatus()).isEqualTo(MailStatus.DEAD);
        assertThat(m.getAttempts()).isEqualTo(5);
        assertThat(m.getVarsJson()).isEqualTo("{}");
    }

    @Test
    void successMarksSentAndScrubsVars() {
        MailOutbox m = mail();
        m.markFailed("x", NOW, 5);

        m.markSent(NOW);

        assertThat(m.getStatus()).isEqualTo(MailStatus.SENT);
        assertThat(m.getSentAt()).isEqualTo(NOW);
        assertThat(m.getLastError()).isNull();
        assertThat(m.getVarsJson()).isEqualTo("{}");
    }

    @Test
    void longErrorIsTruncated() {
        MailOutbox m = mail();

        m.markFailed("e".repeat(2000), NOW, 5);

        assertThat(m.getLastError()).hasSize(500);
    }

    @Test
    void maskHidesLocalPart() {
        assertThat(MailAddresses.mask("ali.veli@bingol.edu.tr")).isEqualTo("a***@bingol.edu.tr");
        assertThat(MailAddresses.mask(null)).isEqualTo("?");
        assertThat(MailAddresses.isPlausible("a@b.tr")).isTrue();
        assertThat(MailAddresses.isPlausible("a@b.tr\r\nBcc: x@y.z")).isFalse();
        assertThat(MailAddresses.isPlausible("a@@b.tr")).isFalse();
    }
}
