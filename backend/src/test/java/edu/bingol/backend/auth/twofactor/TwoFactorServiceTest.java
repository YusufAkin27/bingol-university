package edu.bingol.backend.auth.twofactor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
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
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.FakeRedis;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.DeviceView;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.LoginChallengeResponse;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** TwoFactorService: challenge, kod dogrulama kalibi, guvenilen cihaz, ayar islemleri (Redis taklidi + bellek ici depo). */
class TwoFactorServiceTest {

    private static final String EMAIL = "ayse.yilmaz@bingol.edu.tr";
    private static final String PW = "Kx7-mQ2vLp9z";
    private static final String DEV_A = "a".repeat(64);
    private static final String DEV_B = "b".repeat(64);

    /** Elle ilerletilen saat: lastUsedAt siralamasi deterministik olsun. */
    static final class StepClock extends Clock {
        Instant now = Instant.parse("2026-11-01T10:00:00Z");

        @Override
        public ZoneOffset getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }

        void tick() {
            now = now.plusSeconds(60);
        }
    }

    private final FakeRedis fake = new FakeRedis();
    private final MailService mail = mock(MailService.class);
    private final VerificationService verification = new VerificationService(fake.template, mail);
    private final UserRepository users = mock(UserRepository.class);
    private final InMemoryTwoFactorDevices devices = new InMemoryTwoFactorDevices();
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final StepClock clock = new StepClock();
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final TwoFactorService service =
            new TwoFactorService(users, devices, verification, fake.template, encoder, limiter, clock);

    private final User user = newUser(7L);

    TwoFactorServiceTest() {
        when(users.findById(7L)).thenReturn(Optional.of(user));
    }

    private User newUser(long id) {
        User u = new User();
        u.setId(id);
        u.setEmail(EMAIL);
        u.setPasswordHash(encoder.encode(PW));
        u.setDisplayName("Ayse");
        u.setEmailVerified(true);
        u.setLanguage("en");
        return u;
    }

    private static ClientContext ctx(String device) {
        return new ClientContext("203.0.113.9", device, "ANDROID", "2.0.5");
    }

    /** Son gonderilen kod (e-posta kuyruguna giden). */
    private String lastCode() {
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mail, atLeastOnce()).sendTwoFactorCode(eq(EMAIL), code.capture(), anyInt(), any());
        return code.getValue();
    }

    private static String wrongOf(String code) {
        return code.equals("000000") ? "111111" : "000000";
    }

    // ------------------------------------------------------------------ challenge / kod

    @Test
    void beginStoresAChallengeAndMailsASixDigitCodeInTheUsersLanguage() {
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "mobile");

        assertTrue(r.twoFactorRequired());
        assertEquals(600, r.expiresInSeconds());
        assertEquals("ay***@bingol.edu.tr", r.emailHint());
        assertNotNull(r.challengeToken());
        assertTrue(r.challengeToken().length() >= 40, "yeterli entropi");
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mail).sendTwoFactorCode(eq(EMAIL), code.capture(), eq(10), eq(Lang.EN));
        assertTrue(code.getValue().matches("\\d{6}"));
        // Redis'te ham jeton DEGIL ozeti anahtarlanir; kod yalniz hash'li tutulur
        assertTrue(fake.values.keySet().stream().noneMatch(k -> k.contains(r.challengeToken())));
        assertEquals(1, fake.values.keySet().stream().filter(k -> k.startsWith("2fa:") && !k.startsWith("2fa:att:")).count());
        assertEquals(64, fake.values.get("tf:7").length(), "ozet (SHA-256/HMAC), 6 haneli duz kod degil");
        limiterChecked();
    }

    private void limiterChecked() {
        verify(limiter).check(eq("tf:code:user:7"), eq(10), eq(Duration.ofHours(1)));
    }

    @Test
    void correctCodeConsumesTheChallengeAndItCannotBeReplayed() {
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "mobile");
        String code = lastCode();
        TwoFactorService.Challenge ch = service.peek(r.challengeToken());
        assertEquals(7L, ch.userId());
        assertEquals(DEV_A, ch.deviceHash());
        assertEquals("mobile", ch.client());

        service.verifyAndConsume(r.challengeToken(), ch, code, ctx(DEV_A));

        ApiException gone = assertThrows(ApiException.class, () -> service.peek(r.challengeToken()));
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", gone.code());
        // ayni (tuketilmis) kod yeni bir challenge ile de kabul edilmez
        LoginChallengeResponse r2 = service.begin(user, ctx(DEV_A), "mobile");
        String fresh = lastCode();
        TwoFactorService.Challenge ch2 = service.peek(r2.challengeToken());
        String replay = fresh.equals(code) ? wrongOf(fresh) : code;
        ApiException e = assertThrows(ApiException.class,
                () -> service.verifyAndConsume(r2.challengeToken(), ch2, replay, ctx(DEV_A)));
        assertEquals("TWO_FACTOR_CODE_INVALID", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void wrongCodeIsInvalidAndFiveWrongAttemptsKillTheChallenge() {
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "web");
        String code = lastCode();
        TwoFactorService.Challenge ch = service.peek(r.challengeToken());
        String bad = wrongOf(code);

        for (int i = 0; i < 5; i++) {
            ApiException e = assertThrows(ApiException.class,
                    () -> service.verifyAndConsume(r.challengeToken(), ch, bad, ctx(DEV_A)));
            assertEquals("TWO_FACTOR_CODE_INVALID", e.code());
        }
        // 5. yanlista challenge ve kod silindi: dogru kod bile artik gecmez
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED",
                assertThrows(ApiException.class, () -> service.peek(r.challengeToken())).code());
        assertNull(fake.values.get("tf:7"));
        ApiException late = assertThrows(ApiException.class,
                () -> service.verifyAndConsume(r.challengeToken(), ch, code, ctx(DEV_A)));
        assertEquals("TWO_FACTOR_CODE_INVALID", late.code());
    }

    @Test
    void anExpiredChallengeIsRejected() {
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "web");
        fake.values.keySet().removeIf(k -> k.startsWith("2fa:")); // Redis TTL dolumu

        ApiException e = assertThrows(ApiException.class, () -> service.peek(r.challengeToken()));

        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", e.code());
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class, () -> service.peek("bilinmeyen")).code());
        assertEquals("TWO_FACTOR_CHALLENGE_EXPIRED", assertThrows(ApiException.class, () -> service.peek(null)).code());
    }

    @Test
    void ttlsFollowTheContract() {
        service.begin(user, ctx(DEV_A), "web");

        assertEquals(Duration.ofMinutes(10), fake.ttls.entrySet().stream()
                .filter(en -> en.getKey().startsWith("2fa:")).findFirst().orElseThrow().getValue());
        assertEquals(Duration.ofMinutes(10), fake.ttls.get("tf:7"));
    }

    @Test
    void mailFailureRemovesTheChallengeAndThePendingCode() {
        doThrow(new ApiException(org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE", "x"))
                .when(mail).sendTwoFactorCode(any(), any(), anyInt(), any());

        assertThrows(ApiException.class, () -> service.begin(user, ctx(DEV_A), "web"));

        assertTrue(fake.values.keySet().stream().noneMatch(k -> k.startsWith("2fa:")));
        assertNull(fake.values.get("tf:7"));
    }

    @Test
    void codeMailRateLimitIsEnforcedBeforeAnythingIsStored() {
        doThrow(new RateLimitedException(3000)).when(limiter).check(eq("tf:code:user:7"), anyInt(), any(Duration.class));

        assertThrows(RateLimitedException.class, () -> service.begin(user, ctx(DEV_A), "web"));

        verify(mail, never()).sendTwoFactorCode(any(), any(), anyInt(), any());
        assertTrue(fake.values.isEmpty());
    }

    @Test
    void resendIssuesANewCodeWithoutTheSixtySecondCooldown() {
        LoginChallengeResponse r = service.begin(user, ctx(DEV_A), "web");
        String first = lastCode();
        TwoFactorService.Challenge ch = service.peek(r.challengeToken());

        long ttl = service.resend(r.challengeToken(), ch);

        assertEquals(600, ttl);
        ArgumentCaptor<String> codes = ArgumentCaptor.forClass(String.class);
        verify(mail, org.mockito.Mockito.times(2)).sendTwoFactorCode(eq(EMAIL), codes.capture(), anyInt(), any());
        String second = codes.getAllValues().get(1);
        // yalniz son kod gecerli
        service.verifyAndConsume(r.challengeToken(), ch, second, ctx(DEV_A));
        assertNotNull(first);
    }

    @Test
    void codeDigestIsKeyedByUserIdNotEmail() {
        service.begin(user, ctx(DEV_A), "web");

        assertTrue(fake.values.containsKey("tf:7"));
        assertTrue(fake.values.keySet().stream().noneMatch(k -> k.contains(EMAIL)));
    }

    // ------------------------------------------------------------------ guvenilen cihaz

    @Test
    void unknownOrMissingDeviceIsNotTrusted() {
        assertFalse(service.touchIfTrusted(7L, DEV_A));
        assertFalse(service.touchIfTrusted(7L, null));
    }

    @Test
    void trustedDeviceIsRecognisedAndLastUsedIsUpdated() {
        service.trust(7L, DEV_A, "ANDROID", "2.0.5");
        Instant created = devices.rows.get(0).getLastUsedAt();
        clock.tick();

        assertTrue(service.touchIfTrusted(7L, DEV_A));

        assertTrue(devices.rows.get(0).getLastUsedAt().isAfter(created));
        assertEquals("ANDROID 2.0.5", devices.rows.get(0).getLabel());
        assertFalse(service.touchIfTrusted(7L, DEV_B), "baska cihaz tanimsiz");
        assertFalse(service.touchIfTrusted(8L, DEV_A), "baska kullanicinin cihazi sayilmaz");
    }

    @Test
    void trustingTheSameDeviceTwiceKeepsOneRow() {
        service.trust(7L, DEV_A, "IOS", "2.0.5");
        service.trust(7L, DEV_A, "IOS", "2.0.6");

        assertEquals(1, devices.rows.size());
        assertEquals("IOS 2.0.6", devices.rows.get(0).getLabel());
    }

    @Test
    void atMostTenTrustedDevicesTheOldestIsDropped() {
        for (int i = 0; i < 11; i++) {
            clock.tick();
            service.trust(7L, String.format("%064d", i), "WEB", null);
        }

        assertEquals(10, devices.rows.size());
        assertFalse(service.touchIfTrusted(7L, String.format("%064d", 0)), "en eski dustu");
        assertTrue(service.touchIfTrusted(7L, String.format("%064d", 10)));
    }

    @Test
    void trustWithoutADeviceHashIsANoOp() {
        service.trust(7L, null, "WEB", null);

        assertTrue(devices.rows.isEmpty());
    }

    @Test
    void clearDevicesRemovesOnlyThatUsersRows() {
        service.trust(7L, DEV_A, "WEB", null);
        service.trust(8L, DEV_A, "WEB", null);

        assertEquals(1, service.clearDevices(7L));

        assertEquals(1, devices.rows.size());
        assertEquals(8L, devices.rows.get(0).getUserId());
    }

    @Test
    void labelFormats() {
        assertEquals("ANDROID 2.0.5", TwoFactorService.label("ANDROID", "2.0.5"));
        assertEquals("WEB", TwoFactorService.label("WEB", null));
        assertEquals("2.0.5", TwoFactorService.label("UNKNOWN", "2.0.5"));
        assertNull(TwoFactorService.label("UNKNOWN", null));
        assertNull(TwoFactorService.label(null, null));
    }

    @Test
    void emailHintMasksTheLocalPart() {
        assertEquals("ay***@bingol.edu.tr", TwoFactorService.maskEmail("ayse@bingol.edu.tr"));
        assertEquals("a***@bingol.edu.tr", TwoFactorService.maskEmail("a@bingol.edu.tr"));
        assertEquals("***", TwoFactorService.maskEmail("bozuk"));
        assertEquals("***", TwoFactorService.maskEmail(null));
    }

    // ------------------------------------------------------------------ ayarlar

    @Test
    void enableRequestMailsACodeAndAlreadyEnabledIsConflict() {
        service.requestEnable(7L);
        verify(mail).sendTwoFactorCode(eq(EMAIL), any(), eq(10), eq(Lang.EN));

        user.setTwoFactorEnabled(true);
        ApiException e = assertThrows(ApiException.class, () -> service.requestEnable(7L));
        assertEquals("TWO_FACTOR_ALREADY_ENABLED", e.code());
        assertEquals(409, e.status().value());
    }

    @Test
    void enableConfirmTurnsItOnAndTrustsThisDevice() {
        service.requestEnable(7L);
        String code = lastCode();

        service.confirmEnable(7L, code, ctx(DEV_A));

        assertTrue(user.isTwoFactorEnabled());
        assertNotNull(user.getTwoFactorEnabledAt());
        assertTrue(service.touchIfTrusted(7L, DEV_A));
        verify(users).save(user);
        // tek kullanimlik: ayni kodla ikinci onay (kapaliyken) gecmez
        user.setTwoFactorEnabled(false);
        assertEquals("TWO_FACTOR_CODE_INVALID",
                assertThrows(ApiException.class, () -> service.confirmEnable(7L, code, ctx(DEV_A))).code());
    }

    @Test
    void enableConfirmWithAWrongCodeLeavesItOff() {
        service.requestEnable(7L);
        String code = lastCode();

        ApiException e = assertThrows(ApiException.class, () -> service.confirmEnable(7L, wrongOf(code), ctx(DEV_A)));

        assertEquals("TWO_FACTOR_CODE_INVALID", e.code());
        assertFalse(user.isTwoFactorEnabled());
        assertTrue(devices.rows.isEmpty());
    }

    @Test
    void enableConfirmWithoutADeviceHeaderEnablesButTrustsNothing() {
        service.requestEnable(7L);

        service.confirmEnable(7L, lastCode(), ctx(null));

        assertTrue(user.isTwoFactorEnabled());
        assertTrue(devices.rows.isEmpty());
    }

    @Test
    void disableNeedsTheCorrectPasswordAndWipesTrustedDevices() {
        user.setTwoFactorEnabled(true);
        service.trust(7L, DEV_A, "WEB", null);
        service.trust(7L, DEV_B, "WEB", null);

        ApiException bad = assertThrows(ApiException.class, () -> service.disable(7L, "yanlis-sifre-123"));
        assertEquals("INVALID_PASSWORD", bad.code());
        assertEquals(400, bad.status().value());
        assertTrue(user.isTwoFactorEnabled());
        assertEquals(2, devices.rows.size());
        assertEquals("INVALID_PASSWORD", assertThrows(ApiException.class, () -> service.disable(7L, "x".repeat(80))).code());
        assertEquals("INVALID_PASSWORD", assertThrows(ApiException.class, () -> service.disable(7L, null)).code());

        service.disable(7L, PW);

        assertFalse(user.isTwoFactorEnabled());
        assertNull(user.getTwoFactorEnabledAt());
        assertTrue(devices.rows.isEmpty());
    }

    @Test
    void disableWhenNotEnabledIsConflict() {
        ApiException e = assertThrows(ApiException.class, () -> service.disable(7L, PW));

        assertEquals("TWO_FACTOR_NOT_ENABLED", e.code());
        assertEquals(409, e.status().value());
    }

    @Test
    void forceDisableDoesNotAskForAPasswordAndClearsEverything() {
        user.setTwoFactorEnabled(true);
        service.trust(7L, DEV_A, "WEB", null);
        service.begin(user, ctx(DEV_A), "web");

        service.forceDisable(7L);

        assertFalse(user.isTwoFactorEnabled());
        assertTrue(devices.rows.isEmpty());
        assertNull(fake.values.get("tf:7"), "bekleyen kod da silinir");
        assertEquals("TWO_FACTOR_NOT_ENABLED", assertThrows(ApiException.class, () -> service.forceDisable(7L)).code());
        assertEquals("USER_NOT_FOUND", assertThrows(ApiException.class, () -> service.forceDisable(99L)).code());
    }

    @Test
    void statusAndDeviceListMarkTheCurrentDeviceAndNeverExposeTheHash() {
        user.setTwoFactorEnabled(true);
        service.trust(7L, DEV_A, "ANDROID", "2.0.5");
        clock.tick();
        service.trust(7L, DEV_B, "IOS", "2.0.5");

        TwoFactorDtos.StatusResponse st = service.status(7L, DEV_A);
        assertTrue(st.enabled());
        assertEquals(2, st.trustedDeviceCount());
        assertTrue(st.currentDeviceTrusted());
        assertFalse(service.status(7L, "c".repeat(64)).currentDeviceTrusted());
        assertFalse(service.status(7L, null).currentDeviceTrusted());

        List<DeviceView> list = service.listDevices(7L, DEV_A);
        assertEquals(2, list.size());
        assertEquals("IOS 2.0.5", list.get(0).label(), "son kullanilan once");
        assertFalse(list.get(0).current());
        assertTrue(list.get(1).current());
        assertNotNull(list.get(1).createdAt());
        assertTrue(DeviceView.class.getRecordComponents().length == 5, "ham/ozet kimlik alani yok");
    }

    @Test
    void removeDeviceIsScopedToTheOwnerAndIdempotent() {
        service.trust(7L, DEV_A, "WEB", null);
        service.trust(8L, DEV_B, "WEB", null);
        Long mine = devices.rows.get(0).getId();
        Long theirs = devices.rows.get(1).getId();

        service.removeDevice(7L, theirs);
        assertEquals(2, devices.rows.size(), "baskasinin cihazi silinemez");

        service.removeDevice(7L, mine);
        service.removeDevice(7L, mine);
        assertEquals(1, devices.rows.size());
    }

    @Test
    void suspendedOrMissingUsersCannotUseTheSettingsOperations() {
        user.setStatus(edu.bingol.backend.user.UserStatus.SUSPENDED);

        assertEquals("UNAUTHORIZED", assertThrows(ApiException.class, () -> service.requestEnable(7L)).code());
        assertEquals("UNAUTHORIZED", assertThrows(ApiException.class, () -> service.status(99L, null)).code());
    }
}
