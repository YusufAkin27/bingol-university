package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.FakeRedis;
import edu.bingol.backend.auth.token.CodeResendCooldown;
import edu.bingol.backend.auth.token.ResendCooldownException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.SupportProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.support.ticket.PublicSupportDtos.CodeSent;
import edu.bingol.backend.support.ticket.PublicSupportDtos.SubmitRequest;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.ValueOperations;

/** Herkese acik destek kodu: ayni e-postaya 180 sn icinde ikinci gonderim 429 RESEND_COOLDOWN; dolunca basarili. */
class PublicSupportCooldownTest {

    private final TicketRepository tickets = mock(TicketRepository.class);
    private final SupportMessageRepository messages = mock(SupportMessageRepository.class);
    private final PublicSupportMailer mailer = mock(PublicSupportMailer.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final PublicSupportService svc = new PublicSupportService(tickets, messages,
            mock(SupportTrackTokenRepository.class), mailer, limiter, new SupportProperties(365, "https://x.test", 3));

    private final FakeRedis fake = new FakeRedis();
    private final AtomicLong now = new AtomicLong(0);
    private final Map<String, Long> expiry = new HashMap<>();

    PublicSupportCooldownTest() {
        ValueOperations<String, String> ops = fake.template.opsForValue();
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenAnswer(i -> {
            String k = i.getArgument(0);
            Long exp = expiry.get(k);
            if (fake.values.containsKey(k) && exp != null && exp > now.get()) {
                return false;
            }
            fake.values.put(k, i.getArgument(1));
            expiry.put(k, now.get() + i.<Duration>getArgument(2).toSeconds());
            return true;
        });
        when(fake.template.getExpire(anyString())).thenAnswer(i -> {
            Long exp = expiry.get(i.<String>getArgument(0));
            return exp == null ? -2L : Math.max(0, exp - now.get());
        });
        svc.setCooldown(new CodeResendCooldown(fake.template));
        when(tickets.save(any(SupportTicket.class))).thenAnswer(i -> {
            SupportTicket t = i.getArgument(0);
            if (t.getId() == null) {
                t.setId(7L);
            }
            return t;
        });
        when(messages.save(any(SupportMessage.class))).thenAnswer(i -> i.getArgument(0));
        when(mailer.sendCode(any(), anyString(), anyInt())).thenReturn(true);
    }

    private static SubmitRequest req(String email) {
        return new SubmitRequest("Ali Veli", email, SupportTicket.Category.TECHNICAL,
                "Uygulama acilmiyor, yardim eder misiniz?", "", 9000L);
    }

    @Test
    void secondSubmitWithin180sIs429AndAfter180sSucceeds() {
        CodeSent first = svc.submit(req("ali@example.com"), "1.2.3.4", Lang.TR);
        assertEquals(180, first.resendAfterSeconds());
        assertEquals(10, first.expiresInMinutes()); // kod gecerliligi degismedi
        now.set(45);

        ResendCooldownException e = assertThrows(ResendCooldownException.class,
                () -> svc.submit(req("ali@example.com"), "1.2.3.4", Lang.TR));
        assertEquals(135, e.retryAfterSeconds());
        assertEquals("RESEND_COOLDOWN", e.code());
        verify(mailer, times(1)).sendCode(any(), anyString(), anyInt());

        now.set(180);
        svc.submit(req("ali@example.com"), "1.2.3.4", Lang.TR);
        verify(mailer, times(2)).sendCode(any(), anyString(), anyInt());
    }

    @Test
    void differentEmailsAreIndependent() {
        svc.submit(req("ali@example.com"), "1.2.3.4", Lang.TR);
        svc.submit(req("veli@example.com"), "1.2.3.4", Lang.TR);

        verify(mailer, times(2)).sendCode(any(), anyString(), anyInt());
    }

    @Test
    void honeypotDoesNotStartCooldown() {
        svc.submit(new SubmitRequest("Bot", "ali@example.com", SupportTicket.Category.OTHER, "spam spam spam spam",
                "http://spam", 9000L), "ip", Lang.TR);

        assertTrue(fake.values.keySet().stream().noneMatch(k -> k.startsWith("vcool:")));
        svc.submit(req("ali@example.com"), "1.2.3.4", Lang.TR); // gercek kullanici engellenmez
        verify(mailer, times(1)).sendCode(any(), anyString(), anyInt());
    }

    @Test
    void failedMailReleasesCooldown() {
        when(mailer.sendCode(any(), anyString(), anyInt())).thenReturn(false);
        assertThrows(edu.bingol.backend.common.ApiException.class, () -> svc.submit(req("ali@example.com"), "ip", Lang.TR));

        when(mailer.sendCode(any(), anyString(), anyInt())).thenReturn(true);
        svc.submit(req("ali@example.com"), "ip", Lang.TR); // bekleme geri verilmisti: 429 degil

        verify(mailer, never()).sendReceived(any(), anyString(), anyString());
    }
}
