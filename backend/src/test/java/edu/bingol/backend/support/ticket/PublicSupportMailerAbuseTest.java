package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
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

import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.SupportProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.support.ticket.PublicSupportDtos.SubmitRequest;
import java.time.Duration;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

/** Herkese acik destek: dogrulanmamis adrese giden kodda kullanici adi yok; kota/IP korumasi talepten once. */
class PublicSupportMailerAbuseTest {

    private final MailService mail = mock(MailService.class);
    private final I18n i18n = mock(I18n.class);
    private final AppSettingRepository settings = mock(AppSettingRepository.class);
    private final PublicSupportMailer mailer = new PublicSupportMailer(mail, i18n,
            new SupportProperties(365, "https://x.test", 3), settings);

    private static SupportTicket ticket(String name) {
        SupportTicket t = new SupportTicket();
        t.setContactEmail("kurban@gmail.com");
        t.setContactName(name);
        t.setLang("tr");
        return t;
    }

    @Test
    void codeMailNeverCarriesTheAttackerControlledName() {
        when(i18n.msg(anyString(), any(Lang.class), any(Object[].class))).thenReturn("govde");
        when(i18n.msg(anyString(), any(Lang.class))).thenReturn("konu");
        when(settings.findById(anyString())).thenReturn(Optional.empty());
        when(mail.sendPublicCode(anyString(), anyString(), anyString(), anyString(), anyString())).thenReturn(true);

        boolean ok = mailer.sendCode(ticket("Hesabiniz kilitlendi: https://bu-giris.example/x"), "123456", 10);

        assertTrue(ok);
        // govde sablonuna yalniz kod ve sure gecer (ad yok)
        verify(i18n).msg("mail.support.code.body", Lang.TR, "123456", "10");
        verify(mail).sendPublicCode(eq("kurban@gmail.com"), eq("konu"), eq("govde"), anyString(), anyString());
        // genel (ad-iceren) gonderim yolu kullanilmaz: kota/alici siniri sendPublicCode'da
        verify(mail, never()).sendRich(anyString(), anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void quotaAndLimitViolationsPropagateInsteadOfBeingSwallowed() {
        when(i18n.msg(anyString(), any(Lang.class), any(Object[].class))).thenReturn("govde");
        when(i18n.msg(anyString(), any(Lang.class))).thenReturn("konu");
        when(settings.findById(anyString())).thenReturn(Optional.empty());
        when(mail.sendPublicCode(anyString(), anyString(), anyString(), anyString(), anyString()))
                .thenThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED", "x"));

        ApiException e = assertThrows(ApiException.class, () -> mailer.sendCode(ticket("Ali"), "123456", 10));
        assertEquals("MAIL_QUOTA_EXHAUSTED", e.code());
    }

    @Test
    void safeNameDropsUrlsAndAddressCharacters() {
        assertEquals("Ali Veli", PublicSupportMailer.safeName(ticket("Ali Veli")));
        String evil = PublicSupportMailer.safeName(ticket("Hesabiniz kilitlendi: https://bu-giris.example/x"));
        assertFalse(evil.contains("://"));
        assertFalse(evil.contains("/"));
        assertFalse(evil.contains(":"));
        assertFalse(PublicSupportMailer.safeName(ticket("a@b.com <script>")).contains("@"));
        assertFalse(PublicSupportMailer.safeName(ticket("a@b.com <script>")).contains("<"));
        assertEquals("Şükrü O'Neil-Çelik", PublicSupportMailer.safeName(ticket("Şükrü O'Neil-Çelik")));
        assertTrue(PublicSupportMailer.safeName(ticket("x".repeat(500))).length() <= 60);
        assertEquals("", PublicSupportMailer.safeName(ticket(null)));
    }

    @Test
    void serviceChecksQuotaAndIpBudgetBeforeSavingTheTicketAndNeverMailsWhenRejected() {
        TicketRepository tickets = mock(TicketRepository.class);
        PublicSupportMailer m = mock(PublicSupportMailer.class);
        RateLimiter limiter = mock(RateLimiter.class);
        PublicSupportService svc = new PublicSupportService(tickets, mock(SupportMessageRepository.class),
                mock(SupportTrackTokenRepository.class), m, limiter, new SupportProperties(365, "https://x.test", 3));
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED", "x")).when(m).requireQuota();

        SubmitRequest r = new SubmitRequest("Ali", "ali@example.com", SupportTicket.Category.TECHNICAL,
                "Uygulama acilmiyor, yardim eder misiniz?", "", 9000L);
        assertThrows(ApiException.class, () -> svc.submit(r, "1.2.3.4", Lang.TR));

        verify(tickets, never()).save(any(SupportTicket.class));
        verify(m, never()).sendCode(any(), anyString(), anyInt());
        // IP gunluk + genel saatlik tavan da kuruldu
        verify(limiter).check("pubsup:ipd:1.2.3.4", 15, Duration.ofDays(1));
        verify(limiter).check("pubsup:global", 100, Duration.ofHours(1));
    }
}
