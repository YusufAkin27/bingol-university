package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import tools.jackson.databind.json.JsonMapper;

class MailServiceTest {

    private MailOutboxRepository outbox;
    private MailTransport transport;
    private ApplicationEventPublisher events;
    private MailService service;

    @BeforeEach
    void setUp() {
        outbox = mock(MailOutboxRepository.class);
        transport = mock(MailTransport.class);
        events = mock(ApplicationEventPublisher.class);
        MailProperties props = new MailProperties(false, "no-reply@bingol.edu.tr", "BÜ Kampüs", 5000, 5, 20, false);
        service = new MailService(outbox, transport, props, JsonMapper.builder().build(), events);
    }

    @Test
    void verificationCodeIsQueuedNotSent() throws Exception {
        service.sendVerificationCode("a@bingol.edu.tr", "123456", 10, Lang.EN);

        ArgumentCaptor<MailOutbox> saved = ArgumentCaptor.forClass(MailOutbox.class);
        verify(outbox).save(saved.capture());
        MailOutbox m = saved.getValue();
        assertThat(m.getToAddress()).isEqualTo("a@bingol.edu.tr");
        assertThat(m.getTemplate()).isEqualTo(MailTemplate.VERIFICATION_CODE);
        assertThat(m.getLang()).isEqualTo("en");
        assertThat(m.getStatus()).isEqualTo(MailStatus.PENDING);
        assertThat(m.getAttempts()).isZero();
        assertThat(m.getVarsJson()).contains("\"code\":\"123456\"").contains("\"minutes\":\"10\"");
        verify(events).publishEvent(any(MailQueued.class));
        verify(transport, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void passwordResetUsesResetTemplate() {
        service.sendPasswordResetCode("a@bingol.edu.tr", "111111", 15, Lang.TR);

        ArgumentCaptor<MailOutbox> saved = ArgumentCaptor.forClass(MailOutbox.class);
        verify(outbox).save(saved.capture());
        assertThat(saved.getValue().getTemplate()).isEqualTo(MailTemplate.PASSWORD_RESET_CODE);
    }

    @Test
    void invalidAddressIsRejectedWithoutTouchingDatabase() {
        assertThatThrownBy(() -> service.enqueue("bad\r\naddress", MailTemplate.ACCOUNT_DELETED, Lang.TR, Map.of()))
                .isInstanceOf(ApiException.class);

        verify(outbox, never()).save(any());
    }

    @Test
    void databaseFailureSurfacesAsMailUnavailable() {
        when(outbox.save(any())).thenThrow(new IllegalStateException("db down"));

        assertThatThrownBy(() -> service.sendAccountDeleted("a@bingol.edu.tr", Lang.TR))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void tooLongVariablesAreRejected() {
        assertThatThrownBy(() -> service.sendAnnouncement("a@bingol.edu.tr", "h", "x".repeat(5000), Lang.TR))
                .isInstanceOf(ApiException.class);

        verify(outbox, never()).save(any());
    }

    @Test
    void queueStatsCountsByStatus() {
        when(outbox.countByStatus(MailStatus.PENDING)).thenReturn(3L);
        when(outbox.countByStatus(MailStatus.FAILED)).thenReturn(2L);
        when(outbox.countByStatus(MailStatus.SENT)).thenReturn(10L);
        when(outbox.countByStatus(MailStatus.DEAD)).thenReturn(1L);

        assertThat(service.queueStats()).isEqualTo(new MailService.QueueStats(3, 2, 10, 1));
    }
}
