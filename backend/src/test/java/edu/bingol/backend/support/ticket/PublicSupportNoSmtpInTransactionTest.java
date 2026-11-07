package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.SupportProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.support.ticket.PublicSupportDtos.SubmitRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.data.domain.Pageable;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionOperations;

/**
 * P07-B4/B16: herkese acik destek talebinde SMTP gonderimi veritabani isleminin (ve bagliantisinin) DISINDA calisir;
 * kayit kisa bir islemde yazilir, posta islem bitince gider. E-posta basina gunluk sayac yalniz gecerli jetondan sonra harcanir.
 */
class PublicSupportNoSmtpInTransactionTest {

    private final TicketRepository tickets = mock(TicketRepository.class);
    private final SupportMessageRepository messages = mock(SupportMessageRepository.class);
    private final SupportTrackTokenRepository tokens = mock(SupportTrackTokenRepository.class);
    private final PublicSupportMailer mailer = mock(PublicSupportMailer.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final PublicSupportService svc = new PublicSupportService(tickets, messages, tokens, mailer, limiter,
            new SupportProperties(365, "https://x.test", 3));

    private final AtomicBoolean inTx = new AtomicBoolean();
    private final List<Boolean> txStatesAtMail = new ArrayList<>();
    private int transactions;

    @BeforeEach
    void setUp() {
        svc.setTransactionOperations(new TransactionOperations() {
            @Override
            public <T> T execute(TransactionCallback<T> action) {
                transactions++;
                inTx.set(true);
                try {
                    return action.doInTransaction(mock(TransactionStatus.class));
                } finally {
                    inTx.set(false);
                }
            }
        });
        when(tickets.save(any(SupportTicket.class))).thenAnswer(i -> {
            SupportTicket t = i.getArgument(0);
            if (t.getId() == null) {
                t.setId(7L);
            }
            return t;
        });
        when(tokens.save(any(SupportTrackToken.class))).thenAnswer(i -> i.getArgument(0));
        when(messages.save(any(SupportMessage.class))).thenAnswer(i -> i.getArgument(0));
        when(mailer.sendCode(any(), anyString(), anyInt())).thenAnswer(i -> {
            txStatesAtMail.add(inTx.get());
            return true;
        });
        when(mailer.sendReceived(any(), anyString(), anyString())).thenAnswer(i -> {
            txStatesAtMail.add(inTx.get());
            return true;
        });
    }

    private static SubmitRequest req(String website, Long elapsed) {
        return new SubmitRequest("Ali Veli", "Ali@Example.COM", SupportTicket.Category.TECHNICAL,
                "Uygulama acilmiyor, yardim eder misiniz?", website, elapsed);
    }

    @Test
    void codeMailIsSentOutsideAnyTransactionAfterTicketIsWritten() {
        svc.submit(req("", 9000L), "1.2.3.4", Lang.TR);

        assertEquals(List.of(false), txStatesAtMail, "kod postasi islem icinde gonderilmemeli");
        assertEquals(1, transactions, "kayit tek kisa islem");
        InOrder o = inOrder(tickets, mailer);
        o.verify(tickets).save(any(SupportTicket.class));
        o.verify(mailer).sendCode(any(), anyString(), anyInt());
    }

    @Test
    void mailFailureDeletesTicketInSeparateTransaction() {
        when(mailer.sendCode(any(), anyString(), anyInt())).thenAnswer(i -> {
            txStatesAtMail.add(inTx.get());
            return false;
        });
        txStatesAtMail.clear(); // when(...) eski cevabi bir kez cagirdi

        ApiException e = assertThrows(ApiException.class, () -> svc.submit(req("", 9000L), "1.2.3.4", Lang.TR));

        assertEquals("MAIL_UNAVAILABLE", e.code());
        assertEquals(List.of(false), txStatesAtMail);
        assertEquals(2, transactions, "yaz + sil ayri islemler");
        verify(tickets).delete(any(SupportTicket.class));
    }

    @Test
    void mailerExceptionAlsoRemovesTicket() {
        when(mailer.sendCode(any(), anyString(), anyInt())).thenThrow(new IllegalStateException("smtp"));

        ApiException e = assertThrows(ApiException.class, () -> svc.submit(req("", 9000L), "1.2.3.4", Lang.TR));

        assertEquals("MAIL_UNAVAILABLE", e.code());
        verify(tickets).delete(any(SupportTicket.class));
    }

    @Test
    void receivedMailAfterVerifyIsAlsoOutsideTransaction() {
        SupportTicket t = new SupportTicket();
        t.setId(7L);
        t.setPublicTicket(true);
        t.setEmailVerified(false);
        t.setContactEmail("ali@example.com");
        t.setCodeHash(PublicSupportService.codeHash("ali@example.com", "123456"));
        t.setCodeExpiresAt(Instant.now().plus(Duration.ofMinutes(5)));
        when(tickets.pendingByEmail(eq("ali@example.com"), any(Pageable.class))).thenReturn(List.of(t));
        when(messages.findByTicketIdOrderByIdAsc(7L)).thenReturn(List.of());

        svc.verify("ali@example.com", "123456", "1.2.3.4");

        assertEquals(List.of(false), txStatesAtMail);
        assertTrue(t.isEmailVerified());
    }

    @Test
    void wrongCodeStillPersistsAttemptCounterThenThrows() {
        SupportTicket t = new SupportTicket();
        t.setId(7L);
        t.setPublicTicket(true);
        t.setContactEmail("ali@example.com");
        t.setCodeHash(PublicSupportService.codeHash("ali@example.com", "123456"));
        t.setCodeExpiresAt(Instant.now().plus(Duration.ofMinutes(5)));
        when(tickets.pendingByEmail(eq("ali@example.com"), any(Pageable.class))).thenReturn(List.of(t));

        ApiException e = assertThrows(ApiException.class, () -> svc.verify("ali@example.com", "000000", "ip"));

        assertEquals("INVALID_CODE", e.code());
        assertEquals(1, t.getCodeAttempts());
        verify(tickets).save(t); // islem hata firlatmadan bitti: sayac geri alinmaz
        assertFalse(inTx.get());
        verify(mailer, never()).sendReceived(any(), anyString(), anyString());
    }

    @Test
    void emailDailyCounterIsNotSpentOnDroppedRequests() {
        svc.submit(req("http://spam", 9000L), "ip", Lang.TR); // bal kabagi
        svc.submit(req("", 100L), "ip", Lang.TR); // cok hizli
        verify(limiter, never()).check(org.mockito.ArgumentMatchers.startsWith("pubsup:em:"), anyInt(), any());

        svc.submit(req("", 9000L), "ip", Lang.TR); // gecerli
        verify(limiter).check(org.mockito.ArgumentMatchers.startsWith("pubsup:em:"), eq(5), eq(Duration.ofDays(1)));
    }
}
