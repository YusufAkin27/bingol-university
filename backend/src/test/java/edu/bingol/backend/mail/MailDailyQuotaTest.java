package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MailProperties;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class MailDailyQuotaTest {

    private static MailProperties props(int limit, int reserve, int resetHour) {
        return new MailProperties(true, "noreply@bukampus.online", "BU", 5000, 3, 20, false, "", 30, 300, "", 180, "",
                limit, reserve, resetHour);
    }

    private static void sent(MailDailyQuota q, int n) {
        for (int i = 0; i < n; i++) {
            q.recordSent();
        }
    }

    @Test
    void limitZeroIsUnlimited() {
        MailDailyQuota q = new MailDailyQuota(props(0, 60, 21));
        sent(q, 1000);
        assertThat(q.enabled()).isFalse();
        assertThat(q.allow(true)).isTrue();
        assertThat(q.allow(false)).isTrue();
        assertThat(q.exhausted()).isFalse();
        assertThat(q.used()).isZero();
    }

    @Test
    void counterIncrementsAndReserveClosesAnnouncementsFirst() {
        MailDailyQuota q = new MailDailyQuota(props(10, 4, 21));
        sent(q, 5);
        assertThat(q.used()).isEqualTo(5);
        assertThat(q.allow(true)).isTrue();   // 5 < 10-4
        sent(q, 1);
        assertThat(q.allow(true)).isFalse();  // 6 >= 6: duyuru kapandi
        assertThat(q.allow(false)).isTrue();  // islemsel surer
        sent(q, 4);
        assertThat(q.allow(false)).isFalse();
        assertThat(q.exhausted()).isTrue();
    }

    @Test
    void nextResetIsDayBoundaryPlusMargin() {
        MailDailyQuota q = new MailDailyQuota(props(10, 0, 21));
        // 2026-10-28 10:00 UTC -> kota gunu 27'si 21:00'de basladi; sonraki sifirlama 28'i 21:00 + 5 dk
        assertThat(q.nextReset(Instant.parse("2026-10-28T10:00:00Z"))).isEqualTo(Instant.parse("2026-10-28T21:05:00Z"));
        // 21:30 UTC: gun 28'i 21:00'de basladi -> sonraki 29'u 21:05
        assertThat(q.nextReset(Instant.parse("2026-10-28T21:30:00Z"))).isEqualTo(Instant.parse("2026-10-29T21:05:00Z"));
        // gun anahtari sifirlama saatinde degisir
        assertThat(q.key(Instant.parse("2026-10-28T20:59:00Z"))).isNotEqualTo(q.key(Instant.parse("2026-10-28T21:00:00Z")));
        assertThat(q.key(Instant.parse("2026-10-28T21:00:00Z"))).isEqualTo(q.key(Instant.parse("2026-10-29T20:59:00Z")));
    }

    @Test
    void workerDefersWhenQuotaFullAndKeepsPending() throws Exception {
        MailOutboxRepository outbox = mock(MailOutboxRepository.class);
        MailTransport transport = mock(MailTransport.class);
        MailProperties p = props(2, 0, 21);
        MailDailyQuota q = new MailDailyQuota(p);
        sent(q, 2);
        MailQueueWorker w = new MailQueueWorker(outbox, new MailRenderer(), transport, p, JsonMapper.builder().build(),
                new SimpleMeterRegistry(), null, null, null, q);
        MailOutbox m = new MailOutbox();
        m.setId(9L);
        m.setToAddress("a@bingol.edu.tr");
        m.setTemplate(MailTemplate.SECURITY_PASSWORD_CHANGED);
        m.setLang("tr");
        m.setVarsJson("{\"time\":\"x\"}");
        m.setCreatedAt(Instant.now());
        m.setNextAttemptAt(Instant.now());
        when(outbox.claimDue(any(), any(), anyInt())).thenReturn(List.of(9L));
        when(outbox.findById(9L)).thenReturn(Optional.of(m));
        w.processDue();
        verify(transport, never()).send(any(), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.PENDING);
        assertThat(m.getNextAttemptAt()).isAfter(Instant.now().plusSeconds(60));
    }

    @Test
    void requireCodeQuotaThrowsGeneric503OnlyWhenExhausted() {
        MailProperties p = props(2, 0, 21);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = new MailService(mock(MailOutboxRepository.class), mock(MailTransport.class), p,
                JsonMapper.builder().build(), e -> { }, q);
        svc.requireCodeQuota();
        sent(q, 2);
        assertThatThrownBy(svc::requireCodeQuota).isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).code()).isEqualTo("MAIL_QUOTA_EXHAUSTED");
    }
}
