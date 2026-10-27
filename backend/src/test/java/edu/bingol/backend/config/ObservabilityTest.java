package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.notification.PushDispatcher;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import io.sentry.SentryEvent;
import io.sentry.protocol.Message;
import io.sentry.protocol.Request;
import io.sentry.protocol.SentryException;
import io.sentry.protocol.User;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.messaging.simp.user.SimpSession;
import java.util.Set;

class ObservabilityTest {

    @SuppressWarnings("unchecked")
    private static <T> ObjectProvider<T> provider(T value) {
        ObjectProvider<T> p = mock(ObjectProvider.class);
        when(p.getIfAvailable()).thenReturn(value);
        return p;
    }

    @Test
    void pushCountersReadDispatcher() {
        PushDispatcher d = mock(PushDispatcher.class);
        when(d.deliveredCount()).thenReturn(7L);
        when(d.failureCount()).thenReturn(3L);
        when(d.droppedCount()).thenReturn(2L);
        when(d.retryCount()).thenReturn(1L);
        SimpleMeterRegistry reg = new SimpleMeterRegistry();
        new ObservabilityMetrics().pushMetrics(provider(d)).bindTo(reg);
        assertThat(reg.get("bu.push.delivered").functionCounter().count()).isEqualTo(7.0);
        assertThat(reg.get("bu.push.failures").functionCounter().count()).isEqualTo(3.0);
        assertThat(reg.get("bu.push.dropped").functionCounter().count()).isEqualTo(2.0);
        assertThat(reg.get("bu.push.retries").functionCounter().count()).isEqualTo(1.0);
    }

    @Test
    void missingBeansRegisterNothing() {
        SimpleMeterRegistry reg = new SimpleMeterRegistry();
        ObservabilityMetrics m = new ObservabilityMetrics();
        m.pushMetrics(provider(null)).bindTo(reg);
        m.mailOutboxMetrics(provider(null)).bindTo(reg);
        m.websocketMetrics(provider(null)).bindTo(reg);
        assertThat(reg.getMeters()).isEmpty();
    }

    @Test
    void mailGaugesAreCached() {
        MailService mail = mock(MailService.class);
        when(mail.queueStats()).thenReturn(new MailService.QueueStats(5, 2, 100, 1));
        AtomicLong now = new AtomicLong(1_000);
        ObservabilityMetrics.CachedStats c = new ObservabilityMetrics.CachedStats(mail, now::get);
        assertThat(c.value("pending")).isEqualTo(5.0);
        assertThat(c.value("failed")).isEqualTo(2.0);
        assertThat(c.value("dead")).isEqualTo(1.0);
        verify(mail, times(1)).queueStats();
        now.addAndGet(ObservabilityMetrics.MAIL_CACHE_MS + 1);
        c.value("pending");
        verify(mail, times(2)).queueStats();
    }

    @Test
    void mailGaugeSurvivesDbError() {
        MailService mail = mock(MailService.class);
        when(mail.queueStats()).thenThrow(new IllegalStateException("db"));
        ObservabilityMetrics.CachedStats c = new ObservabilityMetrics.CachedStats(mail, () -> 1L);
        assertThat(c.value("pending")).isNaN();
    }

    @Test
    void websocketGaugesCountSessions() {
        SimpSession s1 = mock(SimpSession.class);
        SimpSession s2 = mock(SimpSession.class);
        SimpUser u = mock(SimpUser.class);
        when(u.getSessions()).thenReturn(Set.of(s1, s2));
        SimpUserRegistry r = mock(SimpUserRegistry.class);
        when(r.getUsers()).thenReturn(Set.of(u));
        when(r.getUserCount()).thenReturn(1);
        SimpleMeterRegistry reg = new SimpleMeterRegistry();
        new ObservabilityMetrics().websocketMetrics(provider(r)).bindTo(reg);
        assertThat(reg.get("bu.websocket.users").gauge().value()).isEqualTo(1.0);
        assertThat(reg.get("bu.websocket.sessions").gauge().value()).isEqualTo(2.0);
    }

    @Test
    void sentryDisabledWithoutDsn() {
        // DSN bos: SDK baslatilmaz, istisna yok
        new ObservabilitySentry("", "", "", 0.0).close();
    }

    @Test
    void scrubRemovesPersonalData() {
        SentryEvent e = new SentryEvent();
        Request req = new Request();
        req.setData("{\"password\":\"abc\"}");
        req.setHeaders(Map.of("Authorization", "Bearer x"));
        req.setCookies("a=b");
        req.setQueryString("token=zzz");
        e.setRequest(req);
        User user = new User();
        user.setEmail("ogrenci@bingol.edu.tr");
        e.setUser(user);
        Message m = new Message();
        m.setFormatted("giris ogrenci@bingol.edu.tr password=hunter2 Bearer abc.def");
        e.setMessage(m);
        SentryException ex = new SentryException();
        ex.setValue("kullanici a.b@bingol.edu.tr bulunamadi");
        e.setExceptions(List.of(ex));

        SentryEvent out = ObservabilitySentry.scrub(e);

        assertThat(out.getRequest().getData()).isNull();
        assertThat(out.getRequest().getHeaders()).isNull();
        assertThat(out.getRequest().getCookies()).isNull();
        assertThat(out.getRequest().getQueryString()).isNull();
        assertThat(out.getUser()).isNull();
        assertThat(out.getMessage().getFormatted()).doesNotContain("bingol.edu.tr", "hunter2", "abc.def");
        assertThat(out.getExceptions().get(0).getValue()).doesNotContain("bingol.edu.tr");
    }

    @Test
    void maskHandlesNullAndJwt() {
        assertThat(ObservabilitySentry.mask(null)).isNull();
        assertThat(ObservabilitySentry.mask("t eyJhbGciOi.eyJzdWIiOi.sig x")).doesNotContain("eyJhbGciOi");
        assertThat(Collections.emptyList()).isEmpty();
    }
}
