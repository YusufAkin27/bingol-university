package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import tools.jackson.databind.json.JsonMapper;

/** Kimliksiz kod postasi kota tuketme saldirisina karsi: pay, alici ve IP sinirlari, sayac kaydi. */
class MailPublicCodeGuardTest {

    private final MailOutboxRepository outbox = mock(MailOutboxRepository.class);
    private final MailTransport transport = mock(MailTransport.class);
    private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);

    private static MailProperties props(int limit) {
        return new MailProperties(true, "noreply@bukampus.online", "BU", 5000, 3, 20, false, "", 30, 300, "", 180, "",
                limit, 60, 21);
    }

    private MailService service(MailProperties p, MailDailyQuota q) {
        return new MailService(outbox, transport, p, JsonMapper.builder().build(), events, q);
    }

    @Test
    void registrationBudgetClosesBeforeTheGlobalQuotaSoRealUsersKeepAReserve() {
        MailProperties p = props(100);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);

        for (int i = 0; i < 60; i++) {
            svc.requireCodeQuota(MailDailyQuota.CodeKind.REGISTRATION);
            svc.sendVerificationCode("u" + i + "@bingol.edu.tr", "123456", 10, Lang.TR);
        }

        // %60 doldu: kayit/kod yenileme kapanir, ama saglayici kotasi (sent) henuz bitmedi
        assertThat(q.publicUsed()).isEqualTo(60);
        assertThatThrownBy(() -> svc.requireCodeQuota(MailDailyQuota.CodeKind.REGISTRATION))
                .isInstanceOf(ApiException.class).extracting(e -> ((ApiException) e).code())
                .isEqualTo("MAIL_QUOTA_EXHAUSTED");
        assertThatThrownBy(() -> svc.requireCodeQuota(MailDailyQuota.CodeKind.SUPPORT))
                .isInstanceOf(ApiException.class);
        // mevcut hesaplarin sifre sifirlamasi (%85'e kadar) hala acik
        svc.requireCodeQuota(MailDailyQuota.CodeKind.PASSWORD_RESET);
    }

    @Test
    void passwordResetKeepsItsOwnExtraShareUntilItIsAlsoFull() {
        MailProperties p = props(100);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);
        for (int i = 0; i < 85; i++) {
            svc.sendPasswordResetCode("r" + i + "@bingol.edu.tr", "111111", 15, Lang.TR);
        }

        assertThat(q.publicExhausted(MailDailyQuota.CodeKind.REGISTRATION)).isTrue();
        assertThat(q.publicExhausted(MailDailyQuota.CodeKind.PASSWORD_RESET)).isTrue();
        assertThatThrownBy(() -> svc.requireCodeQuota(MailDailyQuota.CodeKind.PASSWORD_RESET))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void noArgRequireCodeQuotaUsesRegistrationBudgetWithoutRequestContext() {
        MailProperties p = props(10);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);
        for (int i = 0; i < 6; i++) {
            q.recordPublicCode();
        }
        assertThatThrownBy(svc::requireCodeQuota).isInstanceOf(ApiException.class);
    }

    @Test
    void perRecipientDailyLimitSilentlyDropsExcessCodes() {
        MailProperties p = props(1000);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);

        for (int i = 0; i < 15; i++) {
            svc.sendVerificationCode("victim@bingol.edu.tr", "123456", 10, Lang.TR);
        }

        // varsayilan 10/gun: fazlasi kuyruga hic yazilmaz (istisna yok: hesap varligi sizmaz)
        verify(outbox, times(10)).save(any(MailOutbox.class));
        assertThat(q.publicUsed()).isEqualTo(10);
    }

    @Test
    void differentRecipientsAreCountedSeparately() {
        MailProperties p = props(1000);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);
        for (int i = 0; i < 10; i++) {
            svc.sendVerificationCode("a@bingol.edu.tr", "123456", 10, Lang.TR);
            svc.sendVerificationCode("b@bingol.edu.tr", "123456", 10, Lang.TR);
        }
        verify(outbox, times(20)).save(any(MailOutbox.class));
    }

    @Test
    void perIpDailyRequestCapThrows429() {
        MailProperties p = props(1000);
        MailDailyQuota q = new MailDailyQuota(p);
        q.configure(0.6, 0.85, 10, 3);

        q.checkRequestIp("203.0.113.9");
        q.checkRequestIp("203.0.113.9");
        q.checkRequestIp("203.0.113.9");
        assertThatThrownBy(() -> q.checkRequestIp("203.0.113.9")).isInstanceOf(RateLimitedException.class);
        // baska IP etkilenmez
        q.checkRequestIp("203.0.113.10");
    }

    @Test
    void ipv6AddressesInTheSame64PrefixShareOneBucket() {
        assertThat(MailDailyQuota.ipBucket("2001:db8:1:2:aaaa:bbbb:cccc:dddd"))
                .isEqualTo(MailDailyQuota.ipBucket("2001:db8:1:2:1111:2222:3333:4444"));
        assertThat(MailDailyQuota.ipBucket("2001:db8:1:3::1"))
                .isNotEqualTo(MailDailyQuota.ipBucket("2001:db8:1:2::1"));
        assertThat(MailDailyQuota.ipBucket("203.0.113.9")).isEqualTo("203.0.113.9");

        MailDailyQuota q = new MailDailyQuota(props(1000));
        q.configure(0.6, 0.85, 10, 2);
        q.checkRequestIp("2001:db8:1:2::1");
        q.checkRequestIp("2001:db8:1:2:ffff::2"); // ayni /64: ayni kova
        assertThatThrownBy(() -> q.checkRequestIp("2001:db8:1:2:abcd::3")).isInstanceOf(RateLimitedException.class);
    }

    @Test
    void sendPublicCodeIsCountedInTheProviderQuotaAndPublicBudget() throws Exception {
        MailProperties p = props(100);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);

        boolean ok = svc.sendPublicCode("kimse@example.com", "konu", "govde", "<p>govde</p>", "");

        assertThat(ok).isTrue();
        verify(transport).send(any(), any(), any(), any(), any());
        assertThat(q.used()).isEqualTo(1);       // kuyruk disi gonderim artik kotadan sayilir
        assertThat(q.publicUsed()).isEqualTo(1);
    }

    @Test
    void sendPublicCodeIsRefusedWhenSupportBudgetIsFull() throws Exception {
        MailProperties p = props(10);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);
        for (int i = 0; i < 6; i++) {
            q.recordPublicCode();
        }
        assertThatThrownBy(() -> svc.sendPublicCode("kimse@example.com", "konu", "govde", "<p>x</p>", ""))
                .isInstanceOf(ApiException.class).extracting(e -> ((ApiException) e).code())
                .isEqualTo("MAIL_QUOTA_EXHAUSTED");
        verify(transport, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void sendPublicCodeLimitsPerRecipient() {
        MailProperties p = props(1000);
        MailDailyQuota q = new MailDailyQuota(p);
        q.configure(0.6, 0.85, 2, 100);
        MailService svc = service(p, q);

        assertThat(svc.sendPublicCode("x@example.com", "k", "g", "<p>g</p>", "")).isTrue();
        assertThat(svc.sendPublicCode("x@example.com", "k", "g", "<p>g</p>", "")).isTrue();
        assertThatThrownBy(() -> svc.sendPublicCode("x@example.com", "k", "g", "<p>g</p>", ""))
                .isInstanceOf(RateLimitedException.class);
    }

    @Test
    void protectionIsInertWhenLimitIsZero() {
        MailProperties p = props(0);
        MailDailyQuota q = new MailDailyQuota(p);
        MailService svc = service(p, q);
        for (int i = 0; i < 50; i++) {
            q.recordPublicCode();
        }
        svc.requireCodeQuota(MailDailyQuota.CodeKind.REGISTRATION);
        assertThat(q.publicExhausted(MailDailyQuota.CodeKind.REGISTRATION)).isFalse();
    }
}
