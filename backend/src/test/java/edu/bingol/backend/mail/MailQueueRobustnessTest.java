package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import tools.jackson.databind.json.JsonMapper;

/**
 * P04 mail kuyrugu: kota dolunca bos dongu yok (A04#7), kira baska surece gecince cift gonderim yok (A04#6), nudge
 * birlestirme (A04#6), herkese acik destek kodu kuyruktan (A04#8).
 */
class MailQueueRobustnessTest {

    private MailOutboxRepository outbox;
    private MailTransport transport;
    private MailDailyQuota quota;
    private MailProperties props;
    private MailQueueWorker worker;

    @BeforeEach
    void setUp() {
        outbox = mock(MailOutboxRepository.class);
        transport = mock(MailTransport.class);
        // gunluk limit 10, duyuru payi ayrilmis; 10 posta gitmis -> duyuru tavani dolu
        props = new MailProperties(true, "no-reply@kampus.bingol.edu.tr", "BÜ Kampüs", 5000, 3, 20, false, "", 30, 300,
                "https://kampus.bingol.edu.tr", 180, "", 10, 2, 21);
        quota = mock(MailDailyQuota.class);
        when(quota.allow(true)).thenReturn(false);
        when(quota.allow(false)).thenReturn(true);
        when(quota.nextReset(any())).thenReturn(Instant.parse("2030-01-01T21:05:00Z"));
        worker = new MailQueueWorker(outbox, new MailRenderer(), transport, props, JsonMapper.builder().build(),
                new SimpleMeterRegistry(), null, null, null, quota);
    }

    @Test
    void exhaustedAnnouncementQuotaClaimsNothingAndDefersInOneUpdate() {
        when(outbox.deferAnnouncements(any(), any())).thenReturn(5000);

        worker.processDue();

        // kiralanan duyuru kaydi 0; erteleme TEK toplu UPDATE (kayit basina findById+save yok)
        verify(outbox, never()).claimDueAnnouncements(any(), any(), anyInt());
        verify(outbox, times(1)).deferAnnouncements(any(), eq(Instant.parse("2030-01-01T21:05:00Z")));
        verify(outbox, never()).findById(any());
        verify(outbox, never()).save(any());
    }

    @Test
    void transactionalMailStillClaimedWhenAnnouncementQuotaIsFull() {
        worker.processDue();

        verify(outbox).claimDue(any(), any(), anyInt());
    }

    @Test
    void recordWhoseLeaseWasTakenByAnotherThreadIsNotSentTwice() throws Exception {
        MailOutbox m = new MailOutbox();
        m.setId(7L);
        m.setToAddress("a@bingol.edu.tr");
        m.setTemplate(MailTemplate.SECURITY_PASSWORD_CHANGED);
        m.setLang("tr");
        m.setVarsJson("{\"time\":\"x\"}");
        m.setCreatedAt(Instant.now());
        m.setNextAttemptAt(Instant.now());
        when(quota.allow(false)).thenReturn(true);
        when(outbox.claimDue(any(), any(), anyInt())).thenReturn(List.of(7L));
        when(outbox.findById(7L)).thenReturn(Optional.of(m));
        // kira bu arada baska is parcacigina gecti: guncelleme 0 satir etkiler
        when(outbox.renewLease(eq(7L), any(), any())).thenReturn(0);

        worker.processTransactional();

        verify(transport, never()).send(any(), any(), any(), any(), any());
        verify(outbox, never()).save(any());
    }

    @Test
    void leaseIsRenewedJustBeforeSendingWithTheClaimedValue() throws Exception {
        MailOutbox m = new MailOutbox();
        m.setId(7L);
        m.setToAddress("a@bingol.edu.tr");
        m.setTemplate(MailTemplate.SECURITY_PASSWORD_CHANGED);
        m.setLang("tr");
        m.setVarsJson("{\"time\":\"x\"}");
        m.setCreatedAt(Instant.now());
        m.setNextAttemptAt(Instant.now());
        when(outbox.claimDue(any(), any(), anyInt())).thenReturn(List.of(7L));
        when(outbox.findById(7L)).thenReturn(Optional.of(m));
        when(outbox.renewLease(eq(7L), any(), any())).thenReturn(1);

        worker.processTransactional();

        ArgumentCaptor<Instant> claimed = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> handedOut = ArgumentCaptor.forClass(Instant.class);
        verify(outbox).claimDue(any(), handedOut.capture(), anyInt());
        verify(outbox).renewLease(eq(7L), claimed.capture(), any());
        // yenileme, kayit alinirken verilen kira bitisiyle karsilastirir (milisaniyeye yuvarlanmis)
        assertThat(claimed.getValue()).isEqualTo(handedOut.getValue());
        assertThat(handedOut.getValue().getNano() % 1_000_000).isZero();
        verify(transport).send(eq("a@bingol.edu.tr"), any(), any(), any(), any());
    }

    @Test
    void manyQueuedEventsCollapseIntoAtMostTwoRounds() throws Exception {
        java.util.concurrent.CountDownLatch release = new java.util.concurrent.CountDownLatch(1);
        java.util.concurrent.atomic.AtomicInteger rounds = new java.util.concurrent.atomic.AtomicInteger();
        when(outbox.claimDue(any(), any(), anyInt())).thenAnswer(inv -> {
            rounds.incrementAndGet();
            release.await(2, java.util.concurrent.TimeUnit.SECONDS);
            return List.of();
        });

        for (int i = 0; i < 200; i++) {
            worker.onQueued(new MailQueued());
        }
        Thread.sleep(150);
        release.countDown();
        Thread.sleep(300);

        // 200 olay: biri calisiyor, biri sirada; gerisi birlestirilir (eskiden 200 tur)
        assertThat(rounds.get()).isLessThanOrEqualTo(2);
        assertThat(rounds.get()).isGreaterThanOrEqualTo(1);
        worker.shutdown();
    }

    @Test
    void enqueuePublicCodeWritesToQueueInsteadOfOpeningSmtp() throws Exception {
        MailDailyQuota q = mock(MailDailyQuota.class);
        when(q.exhausted()).thenReturn(false);
        when(q.publicExhausted(MailDailyQuota.CodeKind.SUPPORT)).thenReturn(false);
        when(q.allowRecipientCode("u@gmail.com")).thenReturn(true);
        MailService svc = new MailService(outbox, transport, props, JsonMapper.builder().build(),
                mock(org.springframework.context.ApplicationEventPublisher.class), q);

        svc.enqueuePublicCode("u@gmail.com", "123456", 10, Lang.TR);

        ArgumentCaptor<MailOutbox> saved = ArgumentCaptor.forClass(MailOutbox.class);
        verify(outbox).save(saved.capture());
        assertThat(saved.getValue().getTemplate()).isEqualTo(MailTemplate.SUPPORT_CODE);
        assertThat(saved.getValue().getPriority()).isZero(); // kod = islemsel, duyurulardan once
        assertThat(saved.getValue().getVarsJson()).contains("123456");
        verify(q).recordPublicCode();
        verify(transport, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void enqueuePublicCodeKeepsQuotaGuards() {
        MailDailyQuota q = mock(MailDailyQuota.class);
        when(q.publicExhausted(MailDailyQuota.CodeKind.SUPPORT)).thenReturn(true);
        MailService svc = new MailService(outbox, transport, props, JsonMapper.builder().build(),
                mock(org.springframework.context.ApplicationEventPublisher.class), q);

        org.junit.jupiter.api.Assertions.assertThrows(ApiException.class,
                () -> svc.enqueuePublicCode("u@gmail.com", "123456", 10, Lang.TR));
        verify(outbox, never()).save(any());
    }

    @Test
    void supportCodeMailBecomesStaleAfterTenMinutesLikeOtherCodes() throws Exception {
        MailOutbox m = new MailOutbox();
        m.setId(8L);
        m.setToAddress("u@gmail.com");
        m.setTemplate(MailTemplate.SUPPORT_CODE);
        m.setLang("tr");
        m.setVarsJson("{\"code\":\"123456\",\"minutes\":\"10\"}");
        m.setCreatedAt(Instant.now().minusSeconds(15 * 60));
        m.setNextAttemptAt(Instant.now());
        when(outbox.claimDue(any(), any(), anyInt())).thenReturn(List.of(8L));
        when(outbox.findById(8L)).thenReturn(Optional.of(m));
        when(outbox.renewLease(any(), any(), any())).thenReturn(1);

        worker.processTransactional();

        verify(transport, never()).send(any(), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.DEAD);
        assertThat(m.getVarsJson()).isEqualTo("{}");
    }
}
