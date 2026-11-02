package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.CodeResendCooldown;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.ResendCooldownException;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Kod yeniden isteme beklemesi (180 sn, tek kaynak): her akis, sure dolmadan 429 RESEND_COOLDOWN + Retry-After;
 * sure dolunca basarili; hesap var/yok ayni cevap; farkli e-postalar bagimsiz; ilk gonderim beklemeyi baslatir;
 * kod gecerliligi (10 dk) degismez. Redis TTL'i test saatiyle simule edilir.
 */
class CodeResendCooldownTest {

    private static final String EMAIL = "ali@bingol.edu.tr";
    private static final String OTHER = "veli@bingol.edu.tr";
    private static final String UNKNOWN = "yok@bingol.edu.tr";

    private final FakeRedis fake = new FakeRedis();
    private final AtomicLong now = new AtomicLong(0);
    private final Map<String, Long> expiry = new HashMap<>();
    private final MailService mail = mock(MailService.class);
    private final VerificationService verification = new VerificationService(fake.template, mail);
    private final UserRepository users = mock(UserRepository.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(4), mock(JwtService.class),
            mock(RefreshTokenService.class), verification, new AdminProperties(List.of()), mock(AccountCreator.class),
            pending, mock(SessionService.class), new CatalogService());

    CodeResendCooldownTest() {
        // vcool anahtarlari icin TTL farkindaligi: SET NX PX + sure dolunca anahtar duser (test saati `now`)
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
        User u = new User();
        u.setId(7L);
        u.setEmail(EMAIL);
        u.setEmailVerified(true);
        u.setPasswordHash("h");
        u.setLanguage("tr");
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(u));
        when(users.findByEmail(OTHER)).thenReturn(Optional.of(u));
        when(users.findByEmail(UNKNOWN)).thenReturn(Optional.empty());
    }

    private static ResendCooldownException cooldown(org.junit.jupiter.api.function.Executable r) {
        return assertThrows(ResendCooldownException.class, r);
    }

    private static String keyOf(String flow, String email) {
        return "vcool:" + flow + ":" + Hashing.sha256(email).substring(0, 32);
    }

    // ---- sifre sifirlama: hesap var/yok AYNI davranis

    @Test
    void forgotPasswordSecondRequestWithin180sIs429WithRetryAfterForKnownAndUnknownAccountAlike() {
        auth.forgotPassword(EMAIL);
        auth.forgotPassword(UNKNOWN);
        now.set(60);

        ResendCooldownException known = cooldown(() -> auth.forgotPassword(EMAIL));
        ResendCooldownException unknown = cooldown(() -> auth.forgotPassword(UNKNOWN));

        assertEquals("RESEND_COOLDOWN", known.code());
        assertEquals(known.code(), unknown.code());
        assertEquals(known.status(), unknown.status());
        assertEquals(429, known.status().value());
        assertEquals(120, known.retryAfterSeconds());
        assertEquals(120, unknown.retryAfterSeconds());
        assertTrue(known.retryAfterSeconds() <= 180);
        // mail yalniz bir kez (var olan hesap icin) gitti; reddedilen istekler ve var olmayan hesap mail uretmedi
        verify(mail, times(1)).sendPasswordResetCode(anyString(), anyString(), anyInt(), any());
    }

    @Test
    void forgotPasswordSucceedsAfter180s() {
        auth.forgotPassword(EMAIL);
        now.set(179);
        cooldown(() -> auth.forgotPassword(EMAIL));

        now.set(180);
        auth.forgotPassword(EMAIL);

        verify(mail, times(2)).sendPasswordResetCode(anyString(), anyString(), anyInt(), any());
    }

    @Test
    void cooldownIsIndependentPerEmailAndPerFlow() {
        auth.forgotPassword(EMAIL);

        auth.forgotPassword(OTHER); // baska e-posta etkilenmez
        verification.issue(EMAIL, Lang.TR); // ayni e-posta, baska akis (kayit dogrulama) ayri sayac

        assertTrue(fake.values.containsKey(keyOf("reset", EMAIL)));
        assertTrue(fake.values.containsKey(keyOf("reset", OTHER)));
        assertTrue(fake.values.containsKey(keyOf("verify", EMAIL)));
    }

    @Test
    void cooldownKeyHoldsOnlyADigestAndLivesExactly180Seconds() {
        auth.forgotPassword(EMAIL);

        assertTrue(fake.values.keySet().stream().filter(k -> k.startsWith("vcool:")).noneMatch(k -> k.contains("ali")));
        assertEquals(180L, expiry.get(keyOf("reset", EMAIL)));
    }

    // ---- kayit dogrulama: ilk gonderim beklemeyi baslatir, resend-code ayni sayaci kullanir

    @Test
    void firstSendStartsCooldownAndResendCodeIsRejectedUntil180s() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(pending.find(EMAIL)).thenReturn(new Pending("h", "Ali", "tr"));
        auth.register(EMAIL, "Kx7-mQ2vLp9z", "Ali", Lang.TR);
        now.set(5);

        assertEquals(175, cooldown(() -> auth.resendCode(EMAIL)).retryAfterSeconds());

        now.set(180);
        auth.resendCode(EMAIL); // basarili: yeni kod gitti
        verify(mail, times(2)).sendVerificationCode(anyString(), anyString(), anyInt(), any());
        // yeni gonderim beklemeyi yeniden baslatti
        now.set(181);
        assertEquals(179, cooldown(() -> auth.resendCode(EMAIL)).retryAfterSeconds());
    }

    @Test
    void resendCodeGivesSame429ForUnknownPendingAndKnownPending() {
        when(pending.find(EMAIL)).thenReturn(new Pending("h", "Ali", "tr"));
        when(pending.find(UNKNOWN)).thenReturn(null);
        auth.resendCode(EMAIL);
        auth.resendCode(UNKNOWN);
        now.set(30);

        ResendCooldownException known = cooldown(() -> auth.resendCode(EMAIL));
        ResendCooldownException unknown = cooldown(() -> auth.resendCode(UNKNOWN));

        assertEquals(known.code(), unknown.code());
        assertEquals(known.retryAfterSeconds(), unknown.retryAfterSeconds());
        verify(mail, times(1)).sendVerificationCode(anyString(), anyString(), anyInt(), any());
    }

    // ---- yonetici portali: yetkili / yetkisiz adres resend-code'da AYNI cevabi verir (liste uyeligi sizmaz)

    @Test
    void adminPortalRegisterStartsTheSameCooldownForAuthorizedAndUnauthorizedAddresses() {
        AuthService portal = new AuthService(users, new BCryptPasswordEncoder(4), mock(JwtService.class),
                mock(RefreshTokenService.class), verification, new AdminProperties(List.of("ops@gmail.com")),
                mock(AccountCreator.class), pending, mock(SessionService.class), new CatalogService());
        when(users.findByEmail("ops@gmail.com")).thenReturn(Optional.empty());
        when(users.findByEmail("ogr@bingol.edu.tr")).thenReturn(Optional.empty());
        portal.register("ops@gmail.com", "Kx7-mQ2vLp9z", "Ops", Lang.TR, null, null, null, true);
        portal.register("ogr@bingol.edu.tr", "Kx7-mQ2vLp9z", "Ogr", Lang.TR, null, null, null, true);
        verify(mail, times(1)).sendVerificationCode(anyString(), anyString(), anyInt(), any()); // yalniz yetkiliye kod gitti
        now.set(10);

        ResendCooldownException authorized = cooldown(() -> portal.resendCode("ops@gmail.com"));
        ResendCooldownException unauthorized = cooldown(() -> portal.resendCode("ogr@bingol.edu.tr"));

        assertEquals(authorized.code(), unauthorized.code());
        assertEquals(authorized.retryAfterSeconds(), unauthorized.retryAfterSeconds());
    }

    // ---- 2FA: konu (challenge / etkinlestirme) basina

    @Test
    void twoFactorChallengeAndEnableSubjectsHaveIndependentCooldowns() {
        verification.issueTwoFactor("7:chA", EMAIL, Lang.TR);
        verification.issueTwoFactor("7:enable", EMAIL, Lang.TR); // baska konu: serbest
        now.set(100);
        assertEquals(80, cooldown(() -> verification.issueTwoFactor("7:chA", EMAIL, Lang.TR)).retryAfterSeconds());

        now.set(180);
        verification.issueTwoFactor("7:chA", EMAIL, Lang.TR);
        verify(mail, times(3)).sendTwoFactorCode(anyString(), anyString(), anyInt(), any());
    }

    @Test
    void failedMailReleasesCooldownSoUserIsNotPunished() {
        doThrow(new IllegalStateException("smtp")).when(mail)
                .sendPasswordResetCode(anyString(), anyString(), anyInt(), any());
        assertThrows(IllegalStateException.class, () -> auth.forgotPassword(EMAIL));

        // bekleme geri verildi: hemen tekrar denenebilir (yine SMTP hatasi ama 429 degil)
        assertThrows(IllegalStateException.class, () -> auth.forgotPassword(EMAIL));
    }

    // ---- gecerlilik ve sabitler

    @Test
    void codeValidityStaysTenMinutesAndCooldownIsThreeMinutes() {
        verification.issue(EMAIL, Lang.TR);

        assertEquals(Duration.ofMinutes(10), fake.ttls.get("vc:" + EMAIL));
        assertEquals(180, verification.resendCooldownSeconds());
        assertEquals(180, new CodeResendCooldown(fake.template).seconds());
        assertFalse(fake.values.containsKey("vc:cd:" + EMAIL), "eski ham e-postali bekleme anahtari kullanilmaz");
    }

    @Test
    void configuredCooldownIsHonouredAndNeverBelowOneSecond() {
        CodeResendCooldown c = new CodeResendCooldown(fake.template);
        c.setSeconds(2);
        c.acquire("verify", EMAIL);
        assertEquals(2L, expiry.get(keyOf("verify", EMAIL)));
        c.setSeconds(0);
        assertEquals(1, c.seconds());
    }
}
