package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.i18n.I18n;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.json.JsonMapper;

/** Duyuru akisi: bastirma, hiz siniri, ayni aliciya tekrar siniri, 5xx bounce, islemsel onceligi, kilitli temizlik. */
class MailAnnouncementWorkerTest {

    private MailOutboxRepository outbox;
    private MailTransport transport;
    private MailSuppressionService suppression;
    private SchedulerLock lock;
    private SimpleMeterRegistry metrics;
    private MailProperties props;
    private MailQueueWorker worker;

    @BeforeEach
    void setUp() {
        outbox = mock(MailOutboxRepository.class);
        transport = mock(MailTransport.class);
        suppression = mock(MailSuppressionService.class);
        lock = mock(SchedulerLock.class);
        metrics = new SimpleMeterRegistry();
        props = new MailProperties(true, "no-reply@kampus.bingol.edu.tr", "BÜ Kampüs", 5000, 3, 20, false, "", 30, 300,
                "https://kampus.bingol.edu.tr", 180, "");
        worker = new MailQueueWorker(outbox, new MailRenderer(), transport, props, JsonMapper.builder().build(),
                metrics, suppression, new UnsubscribeTokens(props, "secret"), lock);
    }

    private MailOutbox announcement() {
        MailOutbox m = new MailOutbox();
        m.setId(9L);
        m.setToAddress("a@bingol.edu.tr");
        m.setTemplate(MailTemplate.ANNOUNCEMENT);
        m.setLang("en");
        m.setVarsJson("{\"heading\":\"Hello\",\"message\":\"Body text\"}");
        m.setPriority(1);
        m.setCreatedAt(Instant.now());
        m.setNextAttemptAt(Instant.now());
        when(outbox.claimDueAnnouncements(any(), any(), anyInt())).thenReturn(List.of(9L));
        when(outbox.findById(9L)).thenReturn(Optional.of(m));
        return m;
    }

    @Test
    void announcementIsSentWithListUnsubscribeAndFooter() throws Exception {
        MailOutbox m = announcement();

        worker.processDue();

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> url = ArgumentCaptor.forClass(String.class);
        verify(transport).send(eq("a@bingol.edu.tr"), any(), text.capture(), html.capture(), any(),
                eq(MailCategory.ANNOUNCEMENT), url.capture());
        assertThat(url.getValue()).startsWith("https://kampus.bingol.edu.tr/api/public/mail/unsubscribe?token=")
                .endsWith("&lang=en");
        assertThat(html.getValue()).contains("kampus.bingol.edu.tr</a>");
        assertThat(text.getValue()).contains(url.getValue());
        assertThat(m.getStatus()).isEqualTo(MailStatus.SENT);
    }

    @Test
    void suppressedAddressGetsNoAnnouncement() throws Exception {
        MailOutbox m = announcement();
        when(suppression.isSuppressed("a@bingol.edu.tr")).thenReturn(true);

        worker.processDue();

        verify(transport, never()).send(any(), any(), any(), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.SKIPPED);
        assertThat(m.getVarsJson()).isEqualTo("{}");
        assertThat(metrics.counter("mail.queue.suppressed").count()).isEqualTo(1.0);
    }

    @Test
    void transactionalMailIgnoresSuppressionList() throws Exception {
        MailOutbox m = new MailOutbox();
        m.setId(7L);
        m.setToAddress("a@bingol.edu.tr");
        m.setTemplate(MailTemplate.SECURITY_NEW_LOGIN);
        m.setLang("tr");
        m.setVarsJson("{\"device\":\"x\",\"time\":\"t\"}");
        m.setCreatedAt(Instant.now());
        m.setNextAttemptAt(Instant.now());
        when(suppression.isSuppressed(anyString())).thenReturn(true);
        when(outbox.claimDue(any(), any(), anyInt())).thenReturn(List.of(7L));
        when(outbox.findById(7L)).thenReturn(Optional.of(m));

        worker.processDue();

        verify(transport).send(eq("a@bingol.edu.tr"), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.SENT);
    }

    @Test
    void permanentRecipientFailureSuppressesAndDoesNotRetry() throws Exception {
        MailOutbox m = announcement();
        doThrow(new Exception("550 5.1.1 <a@bingol.edu.tr> User unknown")).when(transport)
                .send(any(), any(), any(), any(), any(), any(), any());

        worker.processDue();

        verify(suppression).suppress("a@bingol.edu.tr", SuppressionReason.BOUNCED);
        assertThat(m.getStatus()).isEqualTo(MailStatus.SKIPPED);
        assertThat(m.getAttempts()).isZero();
        assertThat(metrics.counter("mail.queue.bounced").count()).isEqualTo(1.0);
    }

    @Test
    void temporaryFailureIsRetriedNotSuppressed() throws Exception {
        MailOutbox m = announcement();
        doThrow(new Exception("451 4.2.1 mailbox temporarily unavailable, user unknown yet")).when(transport)
                .send(any(), any(), any(), any(), any(), any(), any());

        worker.processDue();

        verify(suppression, never()).suppress(anyString(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.FAILED);
        assertThat(m.getNextAttemptAt()).isAfter(Instant.now());
    }

    @Test
    void recentAnnouncementToSameRecipientIsDeferred() throws Exception {
        MailOutbox m = announcement();
        when(outbox.existsByToAddressAndPriorityGreaterThanAndStatusAndSentAtAfter(eq("a@bingol.edu.tr"), eq(0),
                eq(MailStatus.SENT), any())).thenReturn(true);

        worker.processDue();

        verify(transport, never()).send(any(), any(), any(), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.PENDING);
        assertThat(m.getNextAttemptAt()).isAfter(Instant.now().plus(Duration.ofSeconds(200)));
    }

    @Test
    void missingUnsubscribeBaseUrlSkipsAnnouncement() throws Exception {
        MailProperties noBase = new MailProperties(true, "a@b.com", "x", 5000, 3, 20, false, "", 30, 300, "", 180, "");
        MailQueueWorker w = new MailQueueWorker(outbox, new MailRenderer(), transport, noBase,
                JsonMapper.builder().build(), metrics, suppression, new UnsubscribeTokens(noBase, "s"), lock);
        MailOutbox m = announcement();

        w.processDue();

        verify(transport, never()).send(any(), any(), any(), any(), any(), any(), any());
        assertThat(m.getStatus()).isEqualTo(MailStatus.SKIPPED);
    }

    @Test
    void announcementBudgetIsPerMinuteLimitMinusRecentlySent() {
        when(outbox.countByPriorityGreaterThanAndStatusAndSentAtAfter(eq(0), eq(MailStatus.SENT), any())).thenReturn(25L);
        assertThat(worker.announcementBudget(Instant.now())).isEqualTo(5);

        when(outbox.countByPriorityGreaterThanAndStatusAndSentAtAfter(eq(0), eq(MailStatus.SENT), any())).thenReturn(40L);
        assertThat(worker.announcementBudget(Instant.now())).isZero();

        when(outbox.countByPriorityGreaterThanAndStatusAndSentAtAfter(eq(0), eq(MailStatus.SENT), any())).thenReturn(0L);
        assertThat(worker.announcementBudget(Instant.now())).isEqualTo(20);
    }

    @Test
    void exhaustedBudgetDoesNotClaimAnnouncementsButStillClaimsTransactional() {
        when(outbox.countByPriorityGreaterThanAndStatusAndSentAtAfter(eq(0), eq(MailStatus.SENT), any())).thenReturn(30L);

        worker.processDue();

        verify(outbox).claimDue(any(), any(), anyInt());
        verify(outbox, never()).claimDueAnnouncements(any(), any(), anyInt());
    }

    @Test
    void purgeRunsUnderSchedulerLock() {
        doAnswer(inv -> {
            ((Runnable) inv.getArgument(2)).run();
            return true;
        }).when(lock).tryRun(eq("mail-purge"), any(), any());

        worker.purgeOld();

        verify(outbox).deleteFinishedBefore(any());
    }

    @Test
    void purgeSkippedWhenLockHeldElsewhere() {
        when(lock.tryRun(eq("mail-purge"), any(), any())).thenReturn(false);

        worker.purgeOld();

        verify(outbox, never()).deleteFinishedBefore(any());
    }

    @Test
    void enqueuedAnnouncementGetsLowPriorityQueue() {
        MailService svc = new MailService(outbox, transport, props, JsonMapper.builder().build(),
                mock(org.springframework.context.ApplicationEventPublisher.class));
        svc.sendAnnouncement("a@bingol.edu.tr", "H", "M", edu.bingol.backend.i18n.Lang.EN);
        svc.sendVerificationCode("a@bingol.edu.tr", "123456", 10, edu.bingol.backend.i18n.Lang.EN);

        ArgumentCaptor<MailOutbox> saved = ArgumentCaptor.forClass(MailOutbox.class);
        verify(outbox, org.mockito.Mockito.times(2)).save(saved.capture());
        assertThat(saved.getAllValues().get(0).getPriority()).isEqualTo(1);
        assertThat(saved.getAllValues().get(1).getPriority()).isZero();
    }

    // ---- Abonelikten cikma ucu ----

    private MailUnsubscribeController controller(MailSuppressionService svc, UnsubscribeTokens tokens) {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasenames("i18n/messages", "i18n/mail");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        I18n i18n = new I18n(ms, null);
        ClientIp ip = mock(ClientIp.class);
        when(ip.of(any())).thenReturn("1.2.3.4");
        return new MailUnsubscribeController(tokens, svc, mock(RateLimiter.class), ip, i18n);
    }

    @Test
    void getShowsConfirmPageWithoutChangingState() {
        UnsubscribeTokens tokens = new UnsubscribeTokens(props, "secret");
        MailUnsubscribeController c = controller(suppression, tokens);
        String token = tokens.create("a@bingol.edu.tr", Instant.now());

        var res = c.confirmPage(token, "ar", mock(HttpServletRequest.class));

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(res.getBody()).contains("dir=\"rtl\"").contains("<form method=\"post\"").contains(token);
        verify(suppression, never()).suppressHash(anyString(), any());
    }

    @Test
    void postSuppressesHashWithUnsubscribedReason() {
        UnsubscribeTokens tokens = new UnsubscribeTokens(props, "secret");
        MailUnsubscribeController c = controller(suppression, tokens);
        String token = tokens.create("A@bingol.edu.tr", Instant.now());

        var res = c.unsubscribe(token, "en", mock(HttpServletRequest.class));

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(res.getBody()).contains("You are unsubscribed");
        verify(suppression).suppressHash(MailSuppressionService.hash("a@bingol.edu.tr"), SuppressionReason.UNSUBSCRIBED);
    }

    @Test
    void invalidTokenGetsGenericBadRequestForBothMethods() {
        MailUnsubscribeController c = controller(suppression, new UnsubscribeTokens(props, "secret"));

        var post = c.unsubscribe("forged.token", "tr", mock(HttpServletRequest.class));
        var get = c.confirmPage(null, "tr", mock(HttpServletRequest.class));

        assertThat(post.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(get.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(post.getBody()).contains("Bağlantı geçersiz");
        verify(suppression, never()).suppressHash(anyString(), any());
    }
}
