package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
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
import edu.bingol.backend.support.ticket.PublicSupportDtos.Verified;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Pageable;

class PublicSupportServiceTest {

    private final TicketRepository tickets = mock(TicketRepository.class);
    private final SupportMessageRepository messages = mock(SupportMessageRepository.class);
    private final SupportTrackTokenRepository tokens = mock(SupportTrackTokenRepository.class);
    private final PublicSupportMailer mailer = mock(PublicSupportMailer.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final PublicSupportService svc = new PublicSupportService(tickets, messages, tokens, mailer, limiter,
            new SupportProperties(365, "https://x.test", 3));

    @BeforeEach
    void setUp() {
        when(tickets.save(any(SupportTicket.class))).thenAnswer(i -> {
            SupportTicket t = i.getArgument(0);
            if (t.getId() == null) {
                t.setId(7L);
            }
            return t;
        });
        when(tokens.save(any(SupportTrackToken.class))).thenAnswer(i -> i.getArgument(0));
        when(messages.save(any(SupportMessage.class))).thenAnswer(i -> i.getArgument(0));
        when(mailer.sendCode(any(), anyString(), anyInt())).thenReturn(true);
        when(mailer.sendReceived(any(), anyString(), anyString())).thenReturn(true);
    }

    private static SubmitRequest req(String website, Long elapsed) {
        return new SubmitRequest("Ali Veli", "Ali@Example.COM", SupportTicket.Category.TECHNICAL,
                "Uygulama acilmiyor, yardim eder misiniz?", website, elapsed);
    }

    private String submitAndCaptureCode() {
        svc.submit(req("", 9000L), "1.2.3.4", Lang.EN);
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mailer).sendCode(any(), code.capture(), anyInt());
        return code.getValue();
    }

    private SupportTicket pendingTicket(String email, String code) {
        SupportTicket t = new SupportTicket();
        t.setId(7L);
        t.setPublicTicket(true);
        t.setEmailVerified(false);
        t.setContactEmail(email);
        t.setContactName("Ali");
        t.setCodeHash(PublicSupportService.codeHash(email, code));
        t.setCodeExpiresAt(Instant.now().plus(Duration.ofMinutes(5)));
        t.setSubject("s");
        t.setCategory(SupportTicket.Category.OTHER);
        return t;
    }

    @Test
    void submitStoresUnverifiedTicketWithHashedCodeAndMailsCode() {
        String code = submitAndCaptureCode();

        ArgumentCaptor<SupportTicket> saved = ArgumentCaptor.forClass(SupportTicket.class);
        verify(tickets).save(saved.capture());
        SupportTicket t = saved.getValue();
        assertFalse(t.isEmailVerified());
        assertTrue(t.isPublicTicket());
        assertNull(t.getUserId());
        assertEquals("ali@example.com", t.getContactEmail());
        assertEquals("en", t.getLang());
        assertEquals(6, code.length());
        assertNotEquals(code, t.getCodeHash());
        assertEquals(PublicSupportService.codeHash("ali@example.com", code), t.getCodeHash());
        verify(limiter).check(eq("pubsup:ip:1.2.3.4"), eq(5), eq(Duration.ofHours(1)));
    }

    @Test
    void honeypotAndTooFastAreSilentlyDropped() {
        assertEquals("CODE_SENT", svc.submit(req("http://spam", 9000L), "ip", Lang.TR).status());
        assertEquals("CODE_SENT", svc.submit(req("", 500L), "ip", Lang.TR).status());
        assertEquals("CODE_SENT", svc.submit(req(null, null), "ip", Lang.TR).status());

        verify(tickets, never()).save(any());
        verify(mailer, never()).sendCode(any(), anyString(), anyInt());
    }

    @Test
    void rateLimitBlocksBeforeAnythingIsStored() {
        doThrow(new ApiException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(anyString(), anyInt(), any());

        assertThrows(ApiException.class, () -> svc.submit(req("", 9000L), "ip", Lang.TR));

        verify(tickets, never()).save(any());
    }

    @Test
    void mailFailureRemovesTicketAndLeaksNothing() {
        when(mailer.sendCode(any(), anyString(), anyInt())).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> svc.submit(req("", 9000L), "ip", Lang.TR));

        assertEquals("MAIL_UNAVAILABLE", e.code());
        verify(tickets).delete(any(SupportTicket.class));
    }

    @Test
    void verifyWithCorrectCodeVerifiesAndStoresOnlyTokenHash() {
        SupportTicket t = pendingTicket("ali@example.com", "123456");
        when(tickets.pendingByEmail(eq("ali@example.com"), any(Pageable.class))).thenReturn(List.of(t));

        Verified v = svc.verify("Ali@Example.com", "123456", "ip");

        assertTrue(t.isEmailVerified());
        assertNull(t.getCodeHash());
        assertEquals(7L, v.ticketId());
        assertTrue(v.trackToken().length() >= 32);
        ArgumentCaptor<SupportTrackToken> row = ArgumentCaptor.forClass(SupportTrackToken.class);
        verify(tokens).save(row.capture());
        assertEquals(Hashing.sha256(v.trackToken()), row.getValue().getTokenHash());
        assertNotEquals(v.trackToken(), row.getValue().getTokenHash());
        verify(mailer).sendReceived(any(), anyString(), eq(v.trackToken()));
    }

    @Test
    void verifyWrongCodeIsGenericAndLimitedToFiveAttempts() {
        SupportTicket t = pendingTicket("ali@example.com", "123456");
        when(tickets.pendingByEmail(anyString(), any(Pageable.class))).thenReturn(List.of(t));

        for (int i = 0; i < 5; i++) {
            ApiException e = assertThrows(ApiException.class, () -> svc.verify("ali@example.com", "000000", "ip"));
            assertEquals("INVALID_CODE", e.code());
        }
        ApiException locked = assertThrows(ApiException.class, () -> svc.verify("ali@example.com", "123456", "ip"));

        assertEquals("TOO_MANY_ATTEMPTS", locked.code());
        assertFalse(t.isEmailVerified());
        assertNull(t.getCodeHash());
    }

    @Test
    void verifyUnknownEmailOrExpiredCodeLooksTheSame() {
        when(tickets.pendingByEmail(anyString(), any(Pageable.class))).thenReturn(List.of());
        assertEquals("INVALID_CODE",
                assertThrows(ApiException.class, () -> svc.verify("nobody@example.com", "123456", "ip")).code());

        SupportTicket t = pendingTicket("ali@example.com", "123456");
        t.setCodeExpiresAt(Instant.now().minusSeconds(1));
        when(tickets.pendingByEmail(eq("ali@example.com"), any(Pageable.class))).thenReturn(List.of(t));
        assertEquals("INVALID_CODE",
                assertThrows(ApiException.class, () -> svc.verify("ali@example.com", "123456", "ip")).code());
    }

    @Test
    void trackLooksUpByHashAndHidesUnverifiedAndUnknown() {
        SupportTicket t = pendingTicket("ali@example.com", "123456");
        SupportTrackToken row = new SupportTrackToken();
        row.setTicketId(7L);
        when(tokens.findByTokenHash(Hashing.sha256("good-token"))).thenReturn(Optional.of(row));
        when(tickets.findById(7L)).thenReturn(Optional.of(t));
        when(messages.findByTicketIdOrderByIdAsc(7L)).thenReturn(List.of());

        // dogrulanmamis talep: 404
        assertEquals("TICKET_NOT_FOUND", assertThrows(ApiException.class, () -> svc.track("good-token", "ip")).code());
        // bilinmeyen anahtar: 404
        assertEquals("TICKET_NOT_FOUND", assertThrows(ApiException.class, () -> svc.track("nope", "ip")).code());

        t.setEmailVerified(true);
        assertEquals(7L, svc.track("good-token", "ip").ticket().id());
        verify(limiter, org.mockito.Mockito.atLeastOnce()).check(eq("pubsup:bad:ip"), anyInt(), any());
    }

    @Test
    void userReplyReopensClosedTicket() {
        SupportTicket t = pendingTicket("ali@example.com", "1");
        t.setEmailVerified(true);
        t.setStatus(SupportTicket.Status.CLOSED);
        t.setClosedAt(Instant.now());
        SupportTrackToken row = new SupportTrackToken();
        row.setTicketId(7L);
        when(tokens.findByTokenHash(Hashing.sha256("tok"))).thenReturn(Optional.of(row));
        when(tickets.findById(7L)).thenReturn(Optional.of(t));
        when(messages.findByTicketIdOrderByIdAsc(7L)).thenReturn(List.of());

        svc.userReply("tok", "  yeni mesaj ", "ip");

        assertEquals(SupportTicket.Status.OPEN, t.getStatus());
        assertNull(t.getClosedAt());
        ArgumentCaptor<SupportMessage> m = ArgumentCaptor.forClass(SupportMessage.class);
        verify(messages).save(m.capture());
        assertFalse(m.getValue().isFromStaff());
        assertNull(m.getValue().getAuthorId());
        assertEquals("yeni mesaj", m.getValue().getText());
    }

    @Test
    void staffReplyMailFailureDoesNotThrow() {
        SupportTicket t = pendingTicket("ali@example.com", "1");
        t.setEmailVerified(true);
        when(tickets.findById(7L)).thenReturn(Optional.of(t));
        when(messages.findByTicketIdOrderByIdAsc(7L)).thenReturn(List.of());
        when(mailer.sendReply(any(), anyString(), anyString(), anyString())).thenThrow(new RuntimeException("smtp down"));

        assertFalse(svc.sendStaffReplyMail(7L, "yanit"));

        org.mockito.Mockito.doReturn(true).when(mailer).sendReply(any(), anyString(), anyString(), anyString());
        assertTrue(svc.sendStaffReplyMail(7L, "yanit"));
    }

    @Test
    void cleanupDeletesUnverifiedAfter24hAndPublicAfterRetention() {
        Instant now = Instant.parse("2026-01-10T00:00:00Z");

        svc.cleanup(now);

        verify(tickets).deleteUnverifiedBefore(now.minus(Duration.ofHours(24)));
        verify(tickets).deletePublicUpdatedBefore(now.minus(Duration.ofDays(365)));
    }

    @Test
    void mailHtmlEscapesRawHtmlAndLinksUrls() {
        String html = PublicSupportMailer.html("<script>alert(1)</script>\nsee https://x.test/a?b=1&c=2", Lang.AR);

        assertFalse(html.contains("<script>"));
        assertTrue(html.contains("&lt;script&gt;"));
        assertTrue(html.contains("<br>"));
        assertTrue(html.contains("<a href=\"https://x.test/a?b=1&amp;c=2\">"));
        assertTrue(html.contains("dir=\"rtl\""));
    }

    @Test
    void normalizeEmailRejectsHeaderInjection() {
        assertEquals("a@b.com", PublicSupportService.normalizeEmail(" A@B.com "));
        assertThrows(ApiException.class, () -> PublicSupportService.normalizeEmail("a@b.com\r\nBcc: x@y.com"));
        assertThrows(ApiException.class, () -> PublicSupportService.normalizeEmail("a@b.com,c@d.com"));
    }
}
