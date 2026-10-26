package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.MailProperties;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class MailQueueWorkerTest {

    private MailOutboxRepository outbox;
    private MailTransport transport;
    private SimpleMeterRegistry metrics;
    private MailQueueWorker worker;

    @BeforeEach
    void setUp() {
        outbox = mock(MailOutboxRepository.class);
        transport = mock(MailTransport.class);
        metrics = new SimpleMeterRegistry();
        worker = workerWith(true);
    }

    private MailQueueWorker workerWith(boolean enabled) {
        MailProperties props = new MailProperties(enabled, "no-reply@bingol.edu.tr", "BÜ Kampüs", 5000, 2, 20, false);
        return new MailQueueWorker(outbox, new MailRenderer(), transport, props, JsonMapper.builder().build(),
                metrics);
    }

    private MailOutbox queued() {
        MailOutbox m = new MailOutbox();
        m.setId(7L);
        m.setToAddress("a@bingol.edu.tr");
        m.setTemplate(MailTemplate.VERIFICATION_CODE);
        m.setLang("tr");
        m.setVarsJson("{\"code\":\"123456\",\"minutes\":\"10\"}");
        m.setCreatedAt(Instant.now());
        m.setNextAttemptAt(Instant.now());
        when(outbox.claimDue(any(), any(), anyInt())).thenReturn(List.of(7L));
        when(outbox.findById(7L)).thenReturn(Optional.of(m));
        return m;
    }

    @Test
    void successfulSendMarksSent() throws Exception {
        MailOutbox m = queued();

        worker.processDue();

        verify(transport).send(eq("a@bingol.edu.tr"), any(), any(), any(), any());
        verify(outbox).save(m);
        assertThat(m.getStatus()).isEqualTo(MailStatus.SENT);
        assertThat(metrics.counter("mail.queue.sent").count()).isEqualTo(1.0);
    }

    @Test
    void failureRetriesThenGoesDead() throws Exception {
        MailOutbox m = queued();
        doThrow(new IllegalStateException("smtp down")).when(transport).send(any(), any(), any(), any(), any());

        worker.processDue();
        assertThat(m.getStatus()).isEqualTo(MailStatus.FAILED);
        assertThat(m.getNextAttemptAt()).isAfter(Instant.now());

        worker.processDue();
        assertThat(m.getStatus()).isEqualTo(MailStatus.DEAD);
        assertThat(metrics.counter("mail.queue.dead").count()).isEqualTo(1.0);
        assertThat(metrics.counter("mail.queue.failed").count()).isEqualTo(2.0);
    }

    @Test
    void disabledMailDoesNotUseSmtp() throws Exception {
        MailOutbox m = queued();

        workerWith(false).processDue();

        verify(transport, never()).send(any(), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.SENT);
    }

    @Test
    void staleCodeMailIsKilledWithoutSendingAndScrubbed() throws Exception {
        MailOutbox m = queued();
        m.setCreatedAt(Instant.now().minus(java.time.Duration.ofMinutes(11)));

        worker.processDue();

        verify(transport, never()).send(any(), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.DEAD);
        assertThat(m.getVarsJson()).isEqualTo("{}");
        verify(outbox).save(m);
    }

    @Test
    void purgeDeletesEverythingOlderThanRetention() {
        worker.purgeOld();
        verify(outbox).deleteFinishedBefore(any());
    }

    @Test
    void alreadySentRecordIsSkipped() throws Exception {
        MailOutbox m = queued();
        m.markSent(Instant.now());

        worker.processDue();

        verify(transport, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void repositoryFailureDoesNotLeak() {
        when(outbox.claimDue(any(), any(), anyInt())).thenThrow(new IllegalStateException("db down"));

        worker.processDue();
    }
}
