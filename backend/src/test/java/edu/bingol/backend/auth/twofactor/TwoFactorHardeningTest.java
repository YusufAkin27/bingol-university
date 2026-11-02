package edu.bingol.backend.auth.twofactor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.FakeRedis;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.LoginChallengeResponse;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Guvenlik duzeltme turu (HARDEN): challenge'in iptal/kapatma sonrasi gecersizligi (O4), challenge'a bagli kod (D1),
 * tukenen challenge kilidi (D2), e-posta kotasi (D3), cihaz bosta suresi (O2), bildirim + oturum kapatma (O1) ve
 * oturum iptali olayinda cihaz silme (D5).
 */
class TwoFactorHardeningTest {

    private static final String EMAIL = "ayse.yilmaz@bingol.edu.tr";
    private static final String PW = "Kx7-mQ2vLp9z";
    private static final String DEV_A = "a".repeat(64);
    private static final String DEV_B = "b".repeat(64);

    private final FakeRedis fake = new FakeRedis();
    private final MailService mail = mock(MailService.class);
    private final VerificationService verification = new VerificationService(fake.template, mail);
    private final UserRepository users = mock(UserRepository.class);
    private final InMemoryTwoFactorDevices devices = new InMemoryTwoFactorDevices();
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final TwoFactorServiceTest.StepClock clock = new TwoFactorServiceTest.StepClock();
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final SessionService sessions = mock(SessionService.class);
    private final TwoFactorNotifier notifier = mock(TwoFactorNotifier.class);
    private final TwoFactorService service =
            new TwoFactorService(users, devices, verification, fake.template, encoder, limiter, clock, sessions, notifier);
    private final User user = new User();

    TwoFactorHardeningTest() {
        user.setId(7L);
        user.setEmail(EMAIL);
        user.setPasswordHash(encoder.encode(PW));
        user.setDisplayName("Ayse");
        user.setEmailVerified(true);
        user.setLanguage("tr");
        user.setTwoFactorEnabled(true);
        when(users.findById(7L)).thenReturn(Optional.of(user));
    }

    private static ClientContext ctx(String device) {
        return new ClientContext("203.0.113.9", device, "ANDROID", "2.0.5");
    }

    private String lastCode() {
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mail, atLeastOnce()).sendTwoFactorCode(eq(EMAIL), code.capture(), anyInt(), any());
        List<String> all = code.getAllValues();
        return all.get(all.size() - 1);
    }

    private static String wrongOf(String code) {
        return code.equals("000000") ? "111111" : "000000";
    }

    private void exhaust(LoginChallengeResponse r) {
        String bad = wrongOf(lastCode());
        TwoFactorService.Challenge ch = service.peek(r.challengeToken());
        for (int i = 0; i < TwoFactorService.MAX_CHALLENGE_ATTEMPTS; i++) {
            assertThrows(ApiException.class, () -> service.verifyAndConsume(r.challengeToken(), ch, bad, ctx(DEV_A)));
        }
    }

    // ------------------------------------------------------------------ O4: challenge gecersizligi

    @Test
    void aChallengeOpenedBeforeAPasswordChangeOrRevokeAllCannotBeUsedAfterwards() {
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "web");
        String code = lastCode();
        TwoFactorService.Challenge ch = service.peek(r.challengeToken());

        // sifre degisimi/sifirlama/logout-all: SessionService.revokeAll `pwchg:<uid>` isaretini yazar
        fake.values.put("pwchg:7", String.valueOf(System.currentTimeMillis()));

        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class, () -> service.peek(r.challengeToken())).code());
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> service.verifyAndConsume(r.challengeToken(), ch, code, ctx(DEV_A))).code());
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class, () -> service.resend(r.challengeToken(), ch)).code());
        assertTrue(devices.rows.isEmpty(), "gecersiz challenge cihaz guvenilir yapmaz");
    }

    @Test
    void aChallengeOpenedAfterTheRevocationMarkerIsValid() {
        fake.values.put("pwchg:7", "1700000000000"); // eski bir iptal
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "web");

        TwoFactorService.Challenge ch = service.peek(r.challengeToken());
        service.verifyAndConsume(r.challengeToken(), ch, lastCode(), ctx(DEV_A));

        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class, () -> service.peek(r.challengeToken())).code());
    }

    @Test
    void aLegacyFiveFieldChallengeStillWorksWhileNoRevocationHappened() {
        fake.values.put("2fa:" + edu.bingol.backend.common.Hashing.sha256("legacy-token"), "7|" + DEV_A + "|web|ANDROID|2.0.5");

        assertEquals(7L, service.peek("legacy-token").userId());
    }

    // ------------------------------------------------------------------ D1: kod challenge'a bagli

    @Test
    void aCodeIssuedForAnotherChallengeDoesNotOpenThisOne() {
        LoginChallengeResponse first = service.begin(user, ctx(DEV_A), "web");
        String firstCode = lastCode();
        LoginChallengeResponse second = service.begin(user, ctx(DEV_A), "web");
        String secondCode = lastCode();
        while (secondCode.equals(firstCode)) { // 1e-6: kodlar tesadufen ayni ise ikinciyi yenile
            second = service.begin(user, ctx(DEV_A), "web");
            secondCode = lastCode();
        }
        TwoFactorService.Challenge firstCh = service.peek(first.challengeToken());
        String otherCode = secondCode;

        ApiException e = assertThrows(ApiException.class,
                () -> service.verifyAndConsume(first.challengeToken(), firstCh, otherCode, ctx(DEV_A)));
        assertEquals("TWO_FACTOR_CODE_INVALID", e.code());

        // kendi kodu ile ikisi de ayri ayri gecer
        service.verifyAndConsume(first.challengeToken(), firstCh, firstCode, ctx(DEV_A));
        service.verifyAndConsume(second.challengeToken(), service.peek(second.challengeToken()), secondCode, ctx(DEV_A));
    }

    @Test
    void theEnableCodeIsNotAValidLoginCodeAndViceVersa() {
        user.setTwoFactorEnabled(false);
        service.requestEnable(7L);
        String enableCode = lastCode();
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "web");
        String loginCode = lastCode();
        TwoFactorService.Challenge ch = service.peek(r.challengeToken());
        if (!enableCode.equals(loginCode)) {
            assertEquals("TWO_FACTOR_CODE_INVALID",
                    assertThrows(ApiException.class, () -> service.verifyAndConsume(r.challengeToken(), ch, enableCode, ctx(DEV_A))).code());
        }
        user.setTwoFactorEnabled(false);
        if (!enableCode.equals(loginCode)) {
            assertEquals("TWO_FACTOR_CODE_INVALID",
                    assertThrows(ApiException.class, () -> service.confirmEnable(7L, loginCode, ctx(DEV_A))).code());
        }
        service.confirmEnable(7L, enableCode, ctx(DEV_A));
        assertTrue(user.isTwoFactorEnabled());
    }

    // ------------------------------------------------------------------ D2: tukenen challenge kilidi

    @Test
    void threeExhaustedChallengesLockNewDeviceLoginsFor24HoursAndNotifyOnce() {
        for (int i = 0; i < 2; i++) {
            exhaust(service.begin(user, ctx(DEV_A), "web"));
        }
        // 2 tukenme: henuz kilit yok
        LoginChallengeResponse third = service.begin(user, ctx(DEV_A), "web");
        verify(notifier, never()).notify(any(), any());

        exhaust(third);

        ApiException locked = assertThrows(ApiException.class, () -> service.begin(user, ctx(DEV_A), "web"));
        assertEquals("TWO_FACTOR_LOCKED", locked.code());
        assertEquals(429, locked.status().value());
        verify(notifier, times(1)).notify(user, TwoFactorNotifier.Event.WRONG_CODES);
        assertEquals(Duration.ofHours(24), fake.ttls.get("2fa:lock:7"));
        // kilit kodu gondermez
        verify(mail, times(3)).sendTwoFactorCode(eq(EMAIL), any(), anyInt(), any());
    }

    @Test
    void theWrongCodeNotificationIsAtMostOncePerDay() {
        for (int i = 0; i < 3; i++) {
            exhaust(service.begin(user, ctx(DEV_A), "web"));
        }
        // kilit acilir (sifre sifirlama) ve tekrar 3 tukenme: ayni gun icinde ikinci bildirim yok
        service.onCredentialsChanged(7L);
        for (int i = 0; i < 3; i++) {
            exhaust(service.begin(user, ctx(DEV_A), "web"));
        }

        assertEquals("TWO_FACTOR_LOCKED",
                assertThrows(ApiException.class, () -> service.begin(user, ctx(DEV_A), "web")).code());
        verify(notifier, times(1)).notify(user, TwoFactorNotifier.Event.WRONG_CODES);
    }

    @Test
    void aSuccessfulVerificationResetsTheExhaustedCounter() {
        exhaust(service.begin(user, ctx(DEV_A), "web"));
        exhaust(service.begin(user, ctx(DEV_A), "web"));
        LoginChallengeResponse ok = service.begin(user, ctx(DEV_A), "web");
        service.verifyAndConsume(ok.challengeToken(), service.peek(ok.challengeToken()), lastCode(), ctx(DEV_A));

        exhaust(service.begin(user, ctx(DEV_A), "web"));
        exhaust(service.begin(user, ctx(DEV_A), "web"));

        service.begin(user, ctx(DEV_A), "web"); // hala kilitli degil
        verify(notifier, never()).notify(any(), any());
    }

    @Test
    void resettingThePasswordLiftsTheLock() {
        for (int i = 0; i < 3; i++) {
            exhaust(service.begin(user, ctx(DEV_A), "web"));
        }
        assertThrows(ApiException.class, () -> service.begin(user, ctx(DEV_A), "web"));

        service.onCredentialsChanged(7L);

        assertNull(fake.values.get("2fa:lock:7"));
        service.begin(user, ctx(DEV_A), "web");
    }

    // ------------------------------------------------------------------ D3: e-posta kotasi

    @Test
    void whenTheDailyMailQuotaIsExhaustedNoChallengeIsOpenedAndNoCodeStored() {
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED", "x"))
                .when(mail).requireAccountCodeQuota();

        ApiException e = assertThrows(ApiException.class, () -> service.begin(user, ctx(DEV_A), "web"));

        assertEquals("MAIL_QUOTA_EXHAUSTED", e.code());
        assertEquals(503, e.status().value());
        assertTrue(fake.values.isEmpty(), "challenge acilmadi");
        verify(mail, never()).sendTwoFactorCode(any(), any(), anyInt(), any());
        // etkinlestirme istegi de ayni korumadan gecer
        user.setTwoFactorEnabled(false);
        assertEquals("MAIL_QUOTA_EXHAUSTED", assertThrows(ApiException.class, () -> service.requestEnable(7L)).code());
    }

    // ------------------------------------------------------------------ O2: cihaz bosta suresi

    @Test
    void aTrustedDeviceIdleForMoreThanTheLimitIsNoLongerTrustedAndIsDeleted() {
        service.trust(7L, DEV_A, "ANDROID", "2.0.5");
        service.trust(7L, DEV_B, "IOS", "2.0.5");
        clock.now = clock.now.plus(Duration.ofDays(59));
        assertTrue(service.touchIfTrusted(7L, DEV_A), "59 gun: hala guvenilir (ve son kullanim yenilenir)");
        clock.now = clock.now.plus(Duration.ofDays(2)); // DEV_B 61 gundur kullanilmiyor, DEV_A 2 gundur

        assertFalse(service.touchIfTrusted(7L, DEV_B), "61 gun bosta: guvenilmez");
        assertEquals(1, devices.rows.size(), "suresi dolan kayit silindi");
        assertTrue(service.touchIfTrusted(7L, DEV_A));
    }

    @Test
    void theIdleLimitCanBeConfiguredOrDisabled() {
        service.setDeviceTtlDays(7);
        service.trust(7L, DEV_A, "WEB", null);
        clock.now = clock.now.plus(Duration.ofDays(8));
        assertFalse(service.touchIfTrusted(7L, DEV_A));

        service.setDeviceTtlDays(0);
        service.trust(7L, DEV_B, "WEB", null);
        clock.now = clock.now.plus(Duration.ofDays(2000));
        assertTrue(service.touchIfTrusted(7L, DEV_B), "0 = sinirsiz");
    }

    // ------------------------------------------------------------------ O1: bildirim + oturum kapatma

    @Test
    void enablingNotifiesTheUserAndOnlyClosesSessionsWhenAsked() {
        user.setTwoFactorEnabled(false);
        service.requestEnable(7L);
        service.confirmEnable(7L, lastCode(), ctx(DEV_A));

        verify(notifier).notify(user, TwoFactorNotifier.Event.ENABLED);
        verify(sessions, never()).revokeAll(any());

        user.setTwoFactorEnabled(false);
        service.requestEnable(7L); // onay basarili olunca bekleme kalkar: hemen yeniden kod istenebilir
        service.confirmEnable(7L, lastCode(), ctx(DEV_B), true);

        verify(sessions).revokeAll(7L);
        verify(notifier, times(2)).notify(user, TwoFactorNotifier.Event.ENABLED);
        // bu cihaz oturum kapatmadan SONRA guvenilir yapilir (olay dinleyicisi cihazlari silse bile)
        assertTrue(service.touchIfTrusted(7L, DEV_B));
    }

    @Test
    void disablingNotifiesTheUserAndOnlyClosesSessionsWhenAsked() {
        service.trust(7L, DEV_A, "WEB", null);

        service.disable(7L, PW);

        verify(notifier).notify(user, TwoFactorNotifier.Event.DISABLED_BY_USER);
        verify(sessions, never()).revokeAll(any());
        assertTrue(devices.rows.isEmpty());

        user.setTwoFactorEnabled(true);
        service.disable(7L, PW, true);

        verify(sessions).revokeAll(7L);
        verify(notifier, times(2)).notify(user, TwoFactorNotifier.Event.DISABLED_BY_USER);
    }

    @Test
    void aWrongPasswordNeitherDisablesNorNotifiesNorClosesSessions() {
        assertThrows(ApiException.class, () -> service.disable(7L, "yanlis-sifre-123", true));

        assertTrue(user.isTwoFactorEnabled());
        verify(notifier, never()).notify(any(), any());
        verify(sessions, never()).revokeAll(any());
    }

    // ------------------------------------------------------------------ D5: oturum iptali => guvenilen cihazlar

    @Test
    void revokingAllSessionsAlsoRemovesTheTrustedDevicesButClientOnlyRevocationDoesNot() {
        service.trust(7L, DEV_A, "WEB", null);
        service.trust(8L, DEV_A, "WEB", null);

        // tek cihaz kurali (yalniz mobil oturumlar): cihazlara dokunmaz
        service.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", true, true));
        assertEquals(2, devices.rows.size());

        // refresh yeniden kullanim tespiti, yonetici oturum kapatma, erisim engeli, askiya alma: revokeAll olayi
        service.onSessionsRevoked(new SessionsRevokedEvent(7L));
        assertEquals(1, devices.rows.size());
        assertEquals(8L, devices.rows.get(0).getUserId());
    }

    @Test
    void credentialChangeWipesDevicesTheEnableCodeAndTheLock() {
        service.trust(7L, DEV_A, "WEB", null);
        fake.values.put("2fa:lock:7", "1");
        fake.values.put("2fa:exh:7", "2");
        user.setTwoFactorEnabled(false);
        service.requestEnable(7L);
        user.setTwoFactorEnabled(true);

        service.onCredentialsChanged(7L);

        assertTrue(devices.rows.isEmpty());
        assertNull(fake.values.get("2fa:lock:7"));
        assertNull(fake.values.get("2fa:exh:7"));
        assertNull(fake.values.get("tf:7:enable"));
    }
}
