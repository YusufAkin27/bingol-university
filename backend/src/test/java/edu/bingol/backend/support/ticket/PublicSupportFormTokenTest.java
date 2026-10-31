package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.SupportProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.support.ticket.PublicSupportDtos.SubmitRequest;
import edu.bingol.backend.support.ticket.SupportFormToken.Result;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** T-062 (A16-12): sunucu imzali form jetonu, ortak tavanin kalkmasi, durum baglantisi son kullanmasi. */
class PublicSupportFormTokenTest {

    /** Elle ilerletilen saat. */
    static final class MutableClock extends Clock {
        final AtomicLong ms = new AtomicLong(1_800_000_000_000L);

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return Instant.ofEpochMilli(ms.get());
        }
    }

    private final MutableClock clock = new MutableClock();
    private final SupportFormToken tokens = new SupportFormToken("", "jwt-secret-for-tests-0123456789abcdef", 3, true, clock);

    private final TicketRepository tickets = mock(TicketRepository.class);
    private final SupportMessageRepository messages = mock(SupportMessageRepository.class);
    private final SupportTrackTokenRepository trackTokens = mock(SupportTrackTokenRepository.class);
    private final PublicSupportMailer mailer = mock(PublicSupportMailer.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final PublicSupportService svc = new PublicSupportService(tickets, messages, trackTokens, mailer, limiter,
            new SupportProperties(365, "https://x.test", 3));

    @BeforeEach
    void setUp() {
        svc.setFormTokens(tokens);
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

    private static SubmitRequest req(String token, Long elapsed) {
        return new SubmitRequest("Ali Veli", "ali@example.com", SupportTicket.Category.TECHNICAL,
                "Uygulama acilmiyor, yardim eder misiniz?", "", elapsed, token);
    }

    // --- jeton ---

    @Test
    void tokenIsTooFastUntilMinFillThenOk() {
        String t = tokens.issue();
        clock.ms.addAndGet(1_000);
        assertEquals(Result.TOO_FAST, tokens.verify(t));
        clock.ms.addAndGet(2_500);
        assertEquals(Result.OK, tokens.verify(t));
    }

    @Test
    void tamperedMissingAndExpiredTokensAreInvalid() {
        String t = tokens.issue();
        clock.ms.addAndGet(5_000);
        String[] p = t.split("\\.");
        String forgedTime = p[0] + "." + (Long.parseLong(p[1]) - 60_000) + "." + p[2] + "." + p[3];
        assertEquals(Result.INVALID, tokens.verify(forgedTime));
        assertEquals(Result.INVALID, tokens.verify(t.substring(0, t.length() - 1) + (t.endsWith("0") ? "1" : "0")));
        assertEquals(Result.INVALID, tokens.verify(null));
        assertEquals(Result.INVALID, tokens.verify(""));
        assertEquals(Result.INVALID, tokens.verify("v1.1.2.3"));
        assertEquals(Result.INVALID, tokens.verify("x".repeat(500)));
        clock.ms.addAndGet(SupportFormToken.MAX_AGE_MS + 1);
        assertEquals(Result.INVALID, tokens.verify(t));
    }

    @Test
    void differentSecretsDoNotAcceptEachOthersTokens() {
        SupportFormToken other = new SupportFormToken("", "another-secret-0123456789abcdefghijk", 3, true, clock);
        String t = other.issue();
        clock.ms.addAndGet(5_000);
        assertEquals(Result.INVALID, tokens.verify(t));
        assertNotEquals(t, tokens.issue());
    }

    // --- gonderim ---

    /** Kart gereksinimi: elapsedMs uydurma ile gonderim reddedilir (sessizce dusurulur, kayit/posta yok). */
    @Test
    void fabricatedElapsedMsWithoutTokenIsRejected() {
        assertEquals("CODE_SENT", svc.submit(req(null, 30_000L), "1.2.3.4", Lang.TR).status());
        assertEquals("CODE_SENT", svc.submit(req("uydurma-jeton", 30_000L), "1.2.3.4", Lang.TR).status());

        verify(tickets, never()).save(any());
        verify(mailer, never()).sendCode(any(), anyString(), anyInt());
    }

    @Test
    void tokenSubmittedTooFastIsRejectedEvenIfElapsedMsClaimsOtherwise() {
        String t = tokens.issue();
        clock.ms.addAndGet(500);

        svc.submit(req(t, 60_000L), "1.2.3.4", Lang.TR);

        verify(tickets, never()).save(any());
    }

    @Test
    void validTokenAfterMinFillStoresTicketAndCountsNonceUse() {
        String t = tokens.issue();
        clock.ms.addAndGet(5_000);

        svc.submit(req(t, null), "1.2.3.4", Lang.TR);

        verify(tickets).save(any(SupportTicket.class));
        verify(mailer).sendCode(any(), anyString(), anyInt());
        verify(limiter).check(eq("pubsup:ft:" + SupportFormToken.nonceOf(t)), eq(3), eq(Duration.ofHours(2)));
    }

    /** Ortak 100/sa tavan kalkti: tek saldirgan formu herkese kilitleyemez. */
    @Test
    void sharedGlobalCeilingIsGone() {
        String t = tokens.issue();
        clock.ms.addAndGet(5_000);

        svc.submit(req(t, null), "1.2.3.4", Lang.TR);

        verify(limiter, never()).check(eq("pubsup:global"), anyInt(), any());
        verify(mailer).requireQuota(); // kod butcesi (requireCodeQuota SUPPORT) devrede
    }

    @Test
    void tokenIssuingIsRateLimitedPerIp() {
        PublicSupportDtos.FormToken ft = svc.issueFormToken("9.9.9.9");

        assertNotNull(ft.formToken());
        assertEquals(3, ft.minFillSeconds());
        verify(limiter).check("pubsup:ftip:9.9.9.9", 60, Duration.ofHours(1));
    }

    @Test
    void legacyElapsedMsStillWorksWhenTokenNotRequired() {
        svc.setFormTokens(new SupportFormToken("", "jwt-secret-for-tests-0123456789abcdef", 3, false, clock));

        svc.submit(req(null, 9_000L), "1.2.3.4", Lang.TR);

        verify(tickets).save(any(SupportTicket.class));
    }

    // --- durum baglantisi son kullanmasi ---

    private SupportTicket verifiedTicket(SupportTicket.Status status, Instant closedAt) {
        SupportTicket t = new SupportTicket();
        t.setId(7L);
        t.setPublicTicket(true);
        t.setEmailVerified(true);
        t.setContactEmail("ali@example.com");
        t.setSubject("s");
        t.setCategory(SupportTicket.Category.OTHER);
        t.setStatus(status);
        t.setClosedAt(closedAt);
        return t;
    }

    private void stubToken(String raw, Instant createdAt, SupportTicket t) {
        SupportTrackToken row = new SupportTrackToken();
        row.setTicketId(7L);
        row.setTokenHash(Hashing.sha256(raw));
        row.setCreatedAt(createdAt);
        when(trackTokens.findByTokenHash(Hashing.sha256(raw))).thenReturn(Optional.of(row));
        when(tickets.findById(7L)).thenReturn(Optional.of(t));
        when(messages.findByTicketIdOrderByIdAsc(7L)).thenReturn(java.util.List.of());
    }

    @Test
    void freshTokenOnOpenTicketWorks() {
        stubToken("tok", Instant.now().minus(Duration.ofDays(5)), verifiedTicket(SupportTicket.Status.OPEN, null));
        assertEquals(7L, svc.track("tok", "ip").ticket().id());
    }

    @Test
    void tokenOlderThanLifetimeIsRejected() {
        stubToken("tok", Instant.now().minus(Duration.ofDays(120)), verifiedTicket(SupportTicket.Status.OPEN, null));
        ApiException e = assertThrows(ApiException.class, () -> svc.track("tok", "ip"));
        assertEquals("TICKET_NOT_FOUND", e.code());
    }

    @Test
    void tokenOfLongClosedTicketIsRevoked() {
        stubToken("tok", Instant.now().minus(Duration.ofDays(30)),
                verifiedTicket(SupportTicket.Status.CLOSED, Instant.now().minus(Duration.ofDays(20))));
        ApiException e = assertThrows(ApiException.class, () -> svc.track("tok", "ip"));
        assertEquals("TICKET_NOT_FOUND", e.code());
    }

    @Test
    void recentlyClosedTicketStillTrackableWithinGrace() {
        stubToken("tok", Instant.now().minus(Duration.ofDays(30)),
                verifiedTicket(SupportTicket.Status.CLOSED, Instant.now().minus(Duration.ofDays(2))));
        assertTrue(svc.track("tok", "ip").ticket().id() == 7L);
    }

    @Test
    void cleanupDeletesExpiredAndClosedTokens() {
        when(trackTokens.deleteCreatedBefore(any())).thenReturn(2);
        when(trackTokens.deleteForTicketsClosedBefore(any())).thenReturn(3);
        when(tickets.deleteUnverifiedBefore(any())).thenReturn(1);
        when(tickets.deletePublicUpdatedBefore(any())).thenReturn(0);

        assertEquals(6, svc.cleanup(Instant.now()));
    }
}
