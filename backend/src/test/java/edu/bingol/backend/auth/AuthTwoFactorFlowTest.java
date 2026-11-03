package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.AccessGuard;
import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.accessban.DeviceLogService;
import edu.bingol.backend.auth.dto.LoginRequest;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.auth.twofactor.InMemoryTwoFactorDevices;
import edu.bingol.backend.auth.twofactor.TwoFactorController;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.LoginChallengeResponse;
import edu.bingol.backend.auth.twofactor.TwoFactorNotifier;
import edu.bingol.backend.auth.twofactor.TwoFactorService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.config.RateLimitProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Clock;
import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Iki faktorlu giris akisi uctan uca (controller -> AuthService -> TwoFactorService -> VerificationService; Redis
 * ve cihaz deposu bellek ici, e-posta/JWT/oturum taklit). Sozlesme: docs/TWO_FACTOR_API.md.
 */
class AuthTwoFactorFlowTest {

    private static final String EMAIL = "ayse@bingol.edu.tr";
    private static final String PW = "Kx7-mQ2vLp9z";
    private static final String DEV_A = "device-A-0123456789";
    private static final String DEV_B = "device-B-0123456789";

    private final FakeRedis fake = new FakeRedis();
    private final MailService mail = mock(MailService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final SessionService sessions = mock(SessionService.class);
    private final JwtService jwt = mock(JwtService.class);
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final LoginThrottle throttle = mock(LoginThrottle.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final AccessGuard guard = mock(AccessGuard.class);
    private final InMemoryTwoFactorDevices devices = new InMemoryTwoFactorDevices();
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final ClientIp clientIp = new ClientIp("10.0.0.0/8");
    private final ClientContexts contexts = new ClientContexts(clientIp, "test-hmac-key", "jwt-secret-for-tests-0123456789");
    private final VerificationService verification = new VerificationService(fake.template, mail);
    private final TwoFactorNotifier notifier = mock(TwoFactorNotifier.class);
    private final TwoFactorService twoFactor = new TwoFactorService(users, devices, verification, fake.template, encoder,
            limiter, Clock.systemUTC(), sessions, notifier);
    private final AuthService auth;
    private final AuthController authController;
    private final TwoFactorController tfController;
    private final User user = new User();
    private final Map<Long, User> byId = new HashMap<>();
    private final VerificationService verificationForAuth = mock(VerificationService.class);

    AuthTwoFactorFlowTest() {
        user.setId(5L);
        user.setEmail(EMAIL);
        user.setPasswordHash(encoder.encode(PW));
        user.setDisplayName("Ayse");
        user.setEmailVerified(true);
        user.setLanguage("tr");
        byId.put(5L, user);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(users.findById(5L)).thenAnswer(i -> Optional.ofNullable(byId.get(5L)));
        when(jwt.createAccessToken(any(), anyString())).thenReturn("access");
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
        when(refresh.issue(anyLong(), anyString())).thenReturn("refresh");
        auth = new AuthService(users, encoder, jwt, refresh, verificationForAuth, new AdminProperties(List.of()),
                mock(AccountCreator.class), mock(PendingRegistrationStore.class), sessions, new CatalogService());
        auth.setTwoFactor(twoFactor);
        auth.setAccessControls(guard, mock(DeviceLogService.class));
        I18n i18n = mock(I18n.class);
        when(i18n.current(anyString())).thenReturn("ok");
        authController = new AuthController(auth, limiter, i18n, clientIp, contexts, jwt, throttle,
                RateLimitProperties.defaults(), refresh);
        tfController = new TwoFactorController(auth, twoFactor, limiter, clientIp, contexts,
                RateLimitProperties.defaults(), i18n, jwt);
        // Gercek SessionService gibi: revokeAll `pwchg:<uid>` isaretini yazar (acik challenge'lar bununla gecersizlesir)
        org.mockito.Mockito.doAnswer(i -> {
            fake.values.put("pwchg:" + i.getArgument(0), String.valueOf(System.currentTimeMillis()));
            return null;
        }).when(sessions).revokeAll(any());
    }

    // ------------------------------------------------------------------ yardimcilar

    private static MockHttpServletRequest req(String device) {
        MockHttpServletRequest r = new MockHttpServletRequest();
        r.setRemoteAddr("203.0.113.9");
        if (device != null) {
            r.addHeader("X-Device-Id", device);
            r.addHeader("X-Device-Platform", "android");
            r.addHeader("X-App-Version", "2.0.5");
        }
        return r;
    }

    private ResponseEntity<Object> login(String device) {
        return authController.login(new LoginRequest(EMAIL, PW, "mobile"), req(device));
    }

    private LoginChallengeResponse asChallenge(ResponseEntity<Object> res) {
        assertEquals(HttpStatus.ACCEPTED, res.getStatusCode());
        return assertInstanceOf(LoginChallengeResponse.class, res.getBody());
    }

    private String lastCode() {
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mail, atLeastOnce()).sendTwoFactorCode(eq(EMAIL), code.capture(), anyInt(), any());
        return code.getValue();
    }

    private TokenResponse complete(LoginChallengeResponse ch, String code, boolean trust, String device) {
        return tfController.loginTwoFactor(new TwoFactorDtos.TwoFactorLoginRequest(ch.challengeToken(), code, trust),
                req(device));
    }

    private Authentication principal() {
        return new UsernamePasswordAuthenticationToken(5L, null, List.of());
    }

    private void enableAndTrust(String device) {
        user.setTwoFactorEnabled(true);
        twoFactor.trust(5L, contexts.hash(device), "ANDROID", "2.0.5");
    }

    // ------------------------------------------------------------------ akis

    @Test
    void twoFactorOffGivesAPlain200WithTokensAndNoCode() {
        ResponseEntity<Object> res = login(DEV_A);

        assertEquals(HttpStatus.OK, res.getStatusCode());
        TokenResponse t = assertInstanceOf(TokenResponse.class, res.getBody());
        assertEquals("access", t.accessToken());
        assertEquals("Bearer", t.tokenType());
        verify(mail, never()).sendTwoFactorCode(any(), any(), anyInt(), any());
    }

    @Test
    void enabledAndUnrecognisedDeviceGets202WithoutTokensAndACodeEmail() {
        user.setTwoFactorEnabled(true);

        ResponseEntity<Object> res = login(DEV_A);

        LoginChallengeResponse ch = asChallenge(res);
        assertTrue(ch.twoFactorRequired());
        assertEquals("ay***@bingol.edu.tr", ch.emailHint());
        assertEquals(600, ch.expiresInSeconds());
        assertNotNull(ch.challengeToken());
        verify(refresh, never()).issue(anyLong(), anyString()); // token uretilmedi
        verify(jwt, never()).createAccessToken(any(), anyString());
        verify(sessions, never()).revokeClient(anyLong(), anyString(), org.mockito.ArgumentMatchers.anyBoolean());
        assertEquals(6, lastCode().length());
        // sifre dogru oldugundan kaba kuvvet sayaci sifirlanir
        verify(throttle).recordSuccess(eq(EMAIL), anyString(), eq(contexts.hash(DEV_A)));
        verify(throttle, never()).recordFailure(anyString(), anyString(), any());
    }

    @Test
    void verifyingTheCodeGives200AndTrustsTheDeviceSoTheNextLoginNeedsNoCode() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));

        TokenResponse t = complete(ch, lastCode(), true, DEV_A);

        assertEquals("access", t.accessToken());
        assertTrue(twoFactor.touchIfTrusted(5L, contexts.hash(DEV_A)));
        assertEquals(1, devices.rows.size());
        assertEquals("ANDROID 2.0.5", devices.rows.get(0).getLabel());
        verify(sessions).revokeClient(5L, "mobile", true); // normal giris sonrasi davranislar korunur

        // ayni cihazdan tekrar: kodsuz 200
        ResponseEntity<Object> again = login(DEV_A);
        assertEquals(HttpStatus.OK, again.getStatusCode());
        assertInstanceOf(TokenResponse.class, again.getBody());
        verify(mail, org.mockito.Mockito.times(1)).sendTwoFactorCode(any(), any(), anyInt(), any());
    }

    @Test
    void anotherDeviceStillNeedsACode() {
        enableAndTrust(DEV_A);

        asChallenge(login(DEV_B));

        verify(mail).sendTwoFactorCode(eq(EMAIL), any(), anyInt(), any());
    }

    @Test
    void aRequestWithoutADeviceHeaderAlwaysNeedsACodeEvenOnATrustedAccount() {
        enableAndTrust(DEV_A);

        asChallenge(login(null));
        asChallenge(login(null));

        verify(mail, org.mockito.Mockito.times(2)).sendTwoFactorCode(any(), any(), anyInt(), any());
    }

    @Test
    void trustDeviceFalseSignsInButDoesNotRememberTheDevice() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));

        TokenResponse t = complete(ch, lastCode(), false, DEV_A);

        assertEquals("access", t.accessToken());
        assertTrue(devices.rows.isEmpty());
        asChallenge(login(DEV_A)); // hala kod ister
    }

    @Test
    void wrongPasswordNeverReachesTwoFactorAndStaysTheGenericError() {
        user.setTwoFactorEnabled(true);

        ApiException e = assertThrows(ApiException.class,
                () -> authController.login(new LoginRequest(EMAIL, "yanlis-parola-1", "mobile"), req(DEV_A)));

        assertEquals("INVALID_CREDENTIALS", e.code());
        verify(mail, never()).sendTwoFactorCode(any(), any(), anyInt(), any());
        verify(throttle).recordFailure(eq(EMAIL), anyString(), any());
    }

    @Test
    void suspendedAccountIsRejectedBeforeAnyCodeIsSent() {
        user.setTwoFactorEnabled(true);
        user.setStatus(UserStatus.SUSPENDED);

        ApiException e = assertThrows(ApiException.class, () -> login(DEV_A));

        assertEquals("ACCOUNT_SUSPENDED", e.code());
        verify(mail, never()).sendTwoFactorCode(any(), any(), anyInt(), any());
    }

    @Test
    void accessBlockIsCheckedBeforeTheChallenge() {
        user.setTwoFactorEnabled(true);
        org.mockito.Mockito.doThrow(AccessGuard.accessBlocked()).when(guard).require(any(), eq(5L), eq("/api/auth/login"));

        ApiException e = assertThrows(ApiException.class, () -> login(DEV_A));

        assertEquals("ACCESS_BLOCKED", e.code());
        verify(mail, never()).sendTwoFactorCode(any(), any(), anyInt(), any());
    }

    @Test
    void wrongCodeThenCorrectCodeStillWorksAndTheCodeIsSingleUse() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));
        String code = lastCode();
        String bad = code.equals("000000") ? "111111" : "000000";

        ApiException e = assertThrows(ApiException.class, () -> complete(ch, bad, true, DEV_A));
        assertEquals("TWO_FACTOR_CODE_INVALID", e.code());

        assertNotNull(complete(ch, code, true, DEV_A));
        // challenge tuketildi: ayni kodla ikinci kez olmaz
        ApiException again = assertThrows(ApiException.class, () -> complete(ch, code, true, DEV_A));
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", again.code());
    }

    @Test
    void fiveWrongCodesKillTheChallengeEvenForTheRightCode() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));
        String code = lastCode();
        String bad = code.equals("000000") ? "111111" : "000000";

        for (int i = 0; i < 5; i++) {
            assertEquals("TWO_FACTOR_CODE_INVALID",
                    assertThrows(ApiException.class, () -> complete(ch, bad, true, DEV_A)).code());
        }

        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> complete(ch, code, true, DEV_A)).code());
        verify(refresh, never()).issue(anyLong(), anyString());
    }

    @Test
    void anExpiredOrUnknownChallengeIsRejected() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));
        String code = lastCode();
        fake.values.keySet().removeIf(k -> k.startsWith("2fa:")); // sure doldu

        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> complete(ch, code, true, DEV_A)).code());
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class,
                () -> tfController.loginTwoFactor(new TwoFactorDtos.TwoFactorLoginRequest("uydurma", "123456", true),
                        req(DEV_A))).code());
    }

    @Test
    void accountSuspendedBetweenStepsCannotFinishTheLogin() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));
        String code = lastCode();
        user.setStatus(UserStatus.SUSPENDED);

        ApiException e = assertThrows(ApiException.class, () -> complete(ch, code, true, DEV_A));

        assertEquals("ACCOUNT_SUSPENDED", e.code());
        verify(refresh, never()).issue(anyLong(), anyString());
    }

    @Test
    void resendSendsANewCodeAndTheNewOneWorks() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));
        assertEquals(180, ch.resendAfterSeconds());
        // ilk gonderim beklemeyi baslatti: 180 sn dolmadan yeniden gonderme 429 RESEND_COOLDOWN
        assertEquals("RESEND_COOLDOWN", assertThrows(ApiException.class, () -> tfController.resendLoginCode(
                new TwoFactorDtos.ChallengeRequest(ch.challengeToken()), req(DEV_A))).code());
        fake.values.keySet().removeIf(k -> k.startsWith("vcool:")); // 180 sn gecti

        TwoFactorDtos.ResendResponse r =
                tfController.resendLoginCode(new TwoFactorDtos.ChallengeRequest(ch.challengeToken()), req(DEV_A));

        assertEquals(600, r.expiresInSeconds());
        assertEquals(180, r.resendAfterSeconds());
        verify(mail, org.mockito.Mockito.times(2)).sendTwoFactorCode(eq(EMAIL), any(), anyInt(), any());
        assertNotNull(complete(ch, lastCode(), true, DEV_A));
        // sinir: challenge basina 3 / 10 dk
        // erken (bekleme dolmadan) deneme de controller sinirini harcar: iki cagri (bilinen taviz, bkz. docs/changes/auth.md COOLDOWN)
        verify(limiter, org.mockito.Mockito.times(2)).check(org.mockito.ArgumentMatchers.startsWith("tf2:resend:"), eq(3), eq(Duration.ofMinutes(10)));
        // bilinmeyen challenge icin yeniden gonderme olmaz
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class,
                () -> tfController.resendLoginCode(new TwoFactorDtos.ChallengeRequest("yok"), req(DEV_A))).code());
    }

    @Test
    void controllersLimitEveryStepOfTheLoginFlow() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));
        complete(ch, lastCode(), true, DEV_A);

        verify(limiter).check(org.mockito.ArgumentMatchers.startsWith("tf2:ip:"), anyInt(), any(Duration.class));
        verify(limiter).check(org.mockito.ArgumentMatchers.startsWith("tf2:ch:"), eq(10), eq(Duration.ofMinutes(10)));
    }

    // ------------------------------------------------------------------ guvenilen cihazlarin silinmesi

    @Test
    void passwordResetChangePasswordAndLogoutAllWipeTrustedDevices() {
        enableAndTrust(DEV_A);
        assertEquals(1, devices.rows.size());
        auth.logoutAll(5L);
        assertTrue(devices.rows.isEmpty());

        enableAndTrust(DEV_A);
        auth.changePassword(5L, PW, "Yeni-Sifre-9xQ!", "mobile");
        assertTrue(devices.rows.isEmpty());
        verify(sessions, org.mockito.Mockito.times(2)).revokeAll(5L);
    }

    @Test
    void passwordResetWipesTrustedDevicesToo() {
        enableAndTrust(DEV_A);
        when(verificationForAuth.checkResetToken(EMAIL, "tok")).thenReturn(true);
        when(verificationForAuth.consumeResetToken(EMAIL, "tok")).thenReturn(true);

        auth.resetPassword(EMAIL, "tok", "Yeni-Sifre-9xQ!");

        assertTrue(devices.rows.isEmpty());
        verify(sessions).revokeAll(5L);
        // sifirlamadan sonra ayni cihazdan giris yeniden kod ister
        user.setPasswordHash(encoder.encode("Yeni-Sifre-9xQ!"));
        ResponseEntity<Object> res = authController.login(new LoginRequest(EMAIL, "Yeni-Sifre-9xQ!", "mobile"), req(DEV_A));
        assertEquals(HttpStatus.ACCEPTED, res.getStatusCode());
    }

    // ------------------------------------------------------------------ ayar uclari

    @Test
    void enableFlowThroughTheControllers() {
        tfController.requestEnable(principal(), req(DEV_A));
        String code = lastCode();

        TwoFactorDtos.EnabledResponse on = tfController.confirmEnable(new TwoFactorDtos.CodeRequest(code), principal(), req(DEV_A));

        assertTrue(on.enabled());
        TwoFactorDtos.StatusResponse st = tfController.status(principal(), req(DEV_A));
        assertTrue(st.enabled());
        assertEquals(1, st.trustedDeviceCount());
        assertTrue(st.currentDeviceTrusted());
        assertFalse(tfController.status(principal(), req(DEV_B)).currentDeviceTrusted());
        // bu cihaz acilirken guvenilir yapildi: giris kodsuz
        assertEquals(HttpStatus.OK, login(DEV_A).getStatusCode());
        verify(limiter).check(eq("tf:enreq:user:5"), eq(5), eq(Duration.ofHours(1)));
    }

    @Test
    void disableAsksForThePasswordThroughTheController() {
        enableAndTrust(DEV_A);

        ApiException bad = assertThrows(ApiException.class,
                () -> tfController.disable(new TwoFactorDtos.DisableRequest("yanlis-parola-1"), principal(), req(DEV_A)));
        assertEquals("INVALID_PASSWORD", bad.code());
        assertTrue(user.isTwoFactorEnabled());

        TwoFactorDtos.EnabledResponse off =
                tfController.disable(new TwoFactorDtos.DisableRequest(PW), principal(), req(DEV_A));

        assertFalse(off.enabled());
        assertTrue(devices.rows.isEmpty());
        assertEquals(HttpStatus.OK, login(DEV_B).getStatusCode()); // artik kod istenmez
        verify(limiter, org.mockito.Mockito.times(2)).check(eq("tf:disable:user:5"), eq(5), eq(Duration.ofMinutes(15)));
    }

    @Test
    void deviceListAndRemovalThroughTheController() {
        enableAndTrust(DEV_A);
        twoFactor.trust(5L, contexts.hash(DEV_B), "IOS", "2.0.5");
        List<TwoFactorDtos.DeviceView> list = tfController.devices(principal(), req(DEV_A));
        assertEquals(2, list.size());
        assertEquals(1, list.stream().filter(TwoFactorDtos.DeviceView::current).count());

        Long other = list.stream().filter(d -> !d.current()).findFirst().orElseThrow().id();
        tfController.removeDevice(other, principal());

        assertEquals(1, tfController.devices(principal(), req(DEV_A)).size());
        // kaldirilan cihaz bir sonraki giriste kod ister
        asChallenge(login(DEV_B));
        // ... ama bu cihaz (mevcut oturum) etkilenmedi
        assertEquals(HttpStatus.OK, login(DEV_A).getStatusCode());
    }

    // ------------------------------------------------------------------ guvenlik duzeltmeleri (HARDEN)

    @Test
    void trustDeviceDefaultsToFalseWhenTheFieldIsMissing() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));

        assertFalse(new TwoFactorDtos.TwoFactorLoginRequest("t", "123456", null).trust());
        assertTrue(new TwoFactorDtos.TwoFactorLoginRequest("t", "123456", true).trust());
        // alan hic gonderilmediyse (eski/ ozensiz istemci) cihaz guvenilir YAPILMAZ
        tfController.loginTwoFactor(new TwoFactorDtos.TwoFactorLoginRequest(ch.challengeToken(), lastCode(), null), req(DEV_A));

        assertTrue(devices.rows.isEmpty());
        asChallenge(login(DEV_A));
    }

    @Test
    void aChallengeIsDeadAfterAPasswordChangeEvenIfTheAttackerKnowsTheCode() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A)); // saldirgan eski parolayla challenge acti
        String code = lastCode();

        auth.changePassword(5L, PW, "Yeni-Sifre-9xQ!", "web"); // kurban parolayi degistirdi (oturumlar kapandi)

        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> complete(ch, code, true, DEV_A)).code());
        assertTrue(devices.rows.isEmpty(), "saldirganin cihazi guvenilir yapilmadi");
        verify(refresh, never()).issue(anyLong(), eq("mobile"));
    }

    @Test
    void aChallengeIsDeadAfterAPasswordResetAndAfterLogoutAll() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch1 = asChallenge(login(DEV_A));
        String code1 = lastCode();
        when(verificationForAuth.checkResetToken(EMAIL, "tok")).thenReturn(true);
        when(verificationForAuth.consumeResetToken(EMAIL, "tok")).thenReturn(true);
        auth.resetPassword(EMAIL, "tok", "Yeni-Sifre-9xQ!");
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> complete(ch1, code1, true, DEV_A)).code());

        user.setPasswordHash(encoder.encode("Yeni-Sifre-9xQ!"));
        LoginChallengeResponse ch2 = asChallenge(authController.login(new LoginRequest(EMAIL, "Yeni-Sifre-9xQ!", "mobile"), req(DEV_A)));
        String code2 = lastCode();
        try {
            Thread.sleep(2);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        auth.logoutAll(5L);
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> complete(ch2, code2, true, DEV_A)).code());
    }

    @Test
    void aChallengeIsDeadOnceTwoFactorWasTurnedOff() {
        user.setTwoFactorEnabled(true);
        LoginChallengeResponse ch = asChallenge(login(DEV_A));
        String code = lastCode();

        twoFactor.disable(5L, PW); // kullanici kapatti (ya da yonetici kurtarma kapatmasi)

        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> complete(ch, code, true, DEV_A)).code());
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class,
                () -> tfController.resendLoginCode(new TwoFactorDtos.ChallengeRequest(ch.challengeToken()), req(DEV_A))).code());
    }

    @Test
    void closeOtherSessionsReturnsAFreshPairForThisDeviceOnlyWhenAsked() {
        tfController.requestEnable(principal(), req(DEV_A));
        TwoFactorDtos.EnabledResponse plain =
                tfController.confirmEnable(new TwoFactorDtos.CodeRequest(lastCode()), principal(), req(DEV_A));
        assertNull(plain.session(), "varsayilan: oturumlar kapanmaz, yeni cift yok (eski istemciler bozulmaz)");
        verify(sessions, never()).revokeAll(5L);

        tfController.disable(new TwoFactorDtos.DisableRequest(PW), principal(), req(DEV_A));
        tfController.requestEnable(principal(), req(DEV_A));
        TwoFactorDtos.EnabledResponse closed = tfController.confirmEnable(
                new TwoFactorDtos.CodeRequest(lastCode(), true), principal(), req(DEV_A));

        verify(sessions).revokeAll(5L);
        assertNotNull(closed.session());
        assertEquals("access", closed.session().accessToken());
        assertEquals("refresh", closed.session().refreshToken());

        TwoFactorDtos.EnabledResponse off =
                tfController.disable(new TwoFactorDtos.DisableRequest(PW, true), principal(), req(DEV_A));
        assertFalse(off.enabled());
        assertNotNull(off.session());
        verify(sessions, org.mockito.Mockito.times(2)).revokeAll(5L);
    }

    @Test
    void anAccountWithTwoFactorCannotSignInWhenTheTwoFactorServiceIsMissing() {
        // fail-closed: 2FA servisi baglanamadiysa 2FA'li hesap kodsuz girmez (eskiden sessizce kapaliydi)
        AuthService bare = new AuthService(users, encoder, jwt, refresh, verificationForAuth, new AdminProperties(List.of()),
                mock(AccountCreator.class), mock(PendingRegistrationStore.class), sessions, new CatalogService());
        user.setTwoFactorEnabled(true);

        ApiException e = assertThrows(ApiException.class, () -> bare.login(EMAIL, PW, "web", contexts.of(req(DEV_A))));

        assertEquals(500, e.status().value());
        verify(jwt, never()).createAccessToken(any(), anyString());
        // 2FA'siz hesap etkilenmez
        user.setTwoFactorEnabled(false);
        assertEquals("access", bare.login(EMAIL, PW, "web", contexts.of(req(DEV_A))).accessToken());
    }
}
