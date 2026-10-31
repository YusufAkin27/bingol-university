package edu.bingol.backend.auth.token;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
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
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class VerificationServiceTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final MailService mail = mock(MailService.class);
    private final VerificationService service = new VerificationService(redis, mail);

    @SuppressWarnings("unchecked")
    private final org.springframework.data.redis.core.SetOperations<String, String> setOps =
            mock(org.springframework.data.redis.core.SetOperations.class);

    VerificationServiceTest() {
        when(redis.opsForValue()).thenReturn(ops);
        when(redis.opsForSet()).thenReturn(setOps);
    }

    @Test
    void newCodeAfterFiveWrongAttemptsFromTheSameClientIsAcceptedT006() {
        // T-006: kapsamli (e-posta, istemci) sayac yeni kodla sifirlanmazdi: 5 yanlis + yeni kod + DOGRU kod = 429
        edu.bingol.backend.auth.FakeRedis fake = new edu.bingol.backend.auth.FakeRedis();
        VerificationService vs = new VerificationService(fake.template, mail);
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        String scope = "203.0.113.9";

        vs.issue(EMAIL, Lang.TR);
        for (int i = 0; i < VerificationService.MAX_ATTEMPTS; i++) {
            assertFalse(vs.verify(EMAIL, "000000", scope));
        }
        fake.values.remove("vc:cd:" + EMAIL); // 60 sn bekleme gecti
        vs.issue(EMAIL, Lang.TR);
        verify(mail, org.mockito.Mockito.times(2)).sendVerificationCode(eq(EMAIL), code.capture(), anyInt(), any());

        assertTrue(vs.verify(EMAIL, code.getAllValues().get(1), scope));
    }

    @Test
    void hourlyTotalLockSurvivesNewCode() {
        edu.bingol.backend.auth.FakeRedis fake = new edu.bingol.backend.auth.FakeRedis();
        VerificationService vs = new VerificationService(fake.template, mail);
        fake.values.put("vc:tot:" + EMAIL, String.valueOf(VerificationService.MAX_HOURLY_WRONG + 1));

        vs.issue(EMAIL, Lang.TR);

        // saatlik toplam asildiysa yeni kod kilidi ACMAZ (tahmin butcesi yenilenemez)
        assertTrue(fake.values.containsKey("vc:lock:" + EMAIL));
    }

    @Test
    void codeDigestIsKeyedWhenAPepperIsConfigured() throws Exception {
        edu.bingol.backend.auth.FakeRedis fake = new edu.bingol.backend.auth.FakeRedis();
        VerificationService vs = new VerificationService(fake.template, mail);
        java.lang.reflect.Field f = VerificationService.class.getDeclaredField("pepper");
        f.setAccessible(true);
        f.set(vs, "test-pepper-secret");
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);

        vs.issue(EMAIL, Lang.TR);
        verify(mail).sendVerificationCode(eq(EMAIL), code.capture(), anyInt(), any());

        String stored = fake.values.get("vc:" + EMAIL);
        assertFalse(stored.equals(Hashing.sha256(EMAIL + ":" + code.getValue())), "tuzsuz SHA-256 olmamali");
        assertTrue(vs.verify(EMAIL, code.getValue()));
    }

    private static String hash(String code) {
        return Hashing.sha256(EMAIL + ":" + code);
    }

    private void storedCode(String code) {
        when(ops.get("vc:" + EMAIL)).thenReturn(hash(code));
    }

    @Test
    void correctCodeIsAcceptedAndConsumedOnce() {
        storedCode("123456");
        when(ops.increment("vc:att:" + EMAIL)).thenReturn(1L);
        when(redis.delete("vc:" + EMAIL)).thenReturn(true, false);

        assertTrue(service.verify(EMAIL, "123456"));
        // Es zamanli ikinci istek ayni kodu kullanamaz.
        assertFalse(service.verify(EMAIL, "123456"));
    }

    @Test
    void wrongCodeIsRejectedAndKeepsStoredCode() {
        storedCode("123456");
        when(ops.increment("vc:att:" + EMAIL)).thenReturn(1L);

        assertFalse(service.verify(EMAIL, "000000"));
        verify(redis, never()).delete("vc:" + EMAIL);
    }

    @Test
    void recordWrongAttemptCountsButNeverConsumesTheStoredCode() {
        // Parola kaniti basarisiz: sayac artar, dogru kod tuketilmez (sahibinin kodu yanmaz)
        storedCode("123456");
        when(ops.increment("vc:sc:" + EMAIL + ":203.0.113.9:att")).thenReturn(1L);
        when(ops.increment("vc:gatt:" + EMAIL)).thenReturn(1L);
        when(ops.increment("vc:tot:" + EMAIL)).thenReturn(1L);

        service.recordWrongAttempt(EMAIL, "203.0.113.9");

        verify(ops).increment("vc:sc:" + EMAIL + ":203.0.113.9:att");
        verify(ops).increment("vc:tot:" + EMAIL);
        verify(redis, never()).delete("vc:" + EMAIL);
    }

    @Test
    void recordWrongAttemptBeyondLimitLocksAndThrows429() {
        storedCode("123456");
        when(ops.increment("vc:att:" + EMAIL)).thenReturn(6L);

        ApiException e = assertThrows(ApiException.class, () -> service.recordWrongAttempt(EMAIL, null));

        assertEquals("TOO_MANY_ATTEMPTS", e.code());
        verify(redis, never()).delete("vc:" + EMAIL);
    }

    @Test
    void missingCodeIsRejectedWithoutCountingAttempts() {
        assertFalse(service.verify(EMAIL, "123456"));
        verify(ops, never()).increment(anyString());
    }

    @Test
    void exceedingAttemptLimitLocksButDoesNotDeleteCode() {
        storedCode("123456");
        when(ops.increment("vc:att:" + EMAIL)).thenReturn((long) VerificationService.MAX_ATTEMPTS + 1);

        ApiException e = assertThrows(ApiException.class, () -> service.verify(EMAIL, "123456"));

        assertEquals("TOO_MANY_ATTEMPTS", e.code());
        verify(ops).set(eq("vc:lock:" + EMAIL), anyString(), any(java.time.Duration.class));
        verify(redis, never()).delete("vc:" + EMAIL);
    }

    @Test
    void lockedEmailIsRejectedEvenWithCorrectCode() {
        when(redis.hasKey("vc:lock:" + EMAIL)).thenReturn(true);
        storedCode("123456");

        ApiException e = assertThrows(ApiException.class, () -> service.verify(EMAIL, "123456"));

        assertEquals("TOO_MANY_ATTEMPTS", e.code());
        verify(ops, never()).increment(anyString());
    }

    @Test
    void issueStoresHashedCodeAndClearsAttemptsAndLock() {
        when(ops.setIfAbsent(eq("vc:cd:" + EMAIL), anyString(), any(java.time.Duration.class))).thenReturn(true);

        service.issue(EMAIL, Lang.TR);

        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(mail).sendVerificationCode(eq(EMAIL), code.capture(), anyInt(), eq(Lang.TR));
        verify(ops).set(eq("vc:" + EMAIL), eq(hash(code.getValue())), any(java.time.Duration.class));
        verify(redis).delete(java.util.List.of("vc:att:" + EMAIL, "vc:lock:" + EMAIL));
    }

    @Test
    void issueWithinCooldownIsRejected() {
        when(ops.setIfAbsent(eq("vc:cd:" + EMAIL), anyString(), any(java.time.Duration.class))).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> service.issue(EMAIL, Lang.TR));

        assertEquals("RESEND_COOLDOWN", e.code());
        verify(mail, never()).sendVerificationCode(anyString(), anyString(), anyInt(), any());
    }

    private static final String SCOPE = "203.0.113.9";

    @Test
    void attemptsAreCountedPerEmailAndClientPair() {
        storedCode("123456");
        when(ops.increment("vc:sc:" + EMAIL + ":" + SCOPE + ":att")).thenReturn(1L);

        assertFalse(service.verify(EMAIL, "000000", SCOPE));

        verify(ops).increment("vc:sc:" + EMAIL + ":" + SCOPE + ":att");
        verify(ops, never()).increment("vc:att:" + EMAIL);
    }

    @Test
    void attackerLockedOnItsOwnClientKeyDoesNotLockTheRealUser() {
        storedCode("123456");
        // saldirgan istemci sayaci asildi -> yalniz o istemcinin kilidi yazilir
        when(ops.increment("vc:sc:" + EMAIL + ":6.6.6.6:att")).thenReturn((long) VerificationService.MAX_ATTEMPTS + 1);

        assertThrows(ApiException.class, () -> service.verify(EMAIL, "000000", "6.6.6.6"));

        verify(ops).set(eq("vc:sc:" + EMAIL + ":6.6.6.6:lock"), anyString(), any(java.time.Duration.class));
        verify(ops, never()).set(eq("vc:lock:" + EMAIL), anyString(), any(java.time.Duration.class));
        // gercek kullanici (baska istemci) hala dogru kodu girebilir
        when(ops.increment("vc:sc:" + EMAIL + ":" + SCOPE + ":att")).thenReturn(1L);
        when(redis.delete("vc:" + EMAIL)).thenReturn(true);
        assertTrue(service.verify(EMAIL, "123456", SCOPE));
    }

    @Test
    void clientLockBlocksOnlyThatClient() {
        when(redis.hasKey("vc:sc:" + EMAIL + ":6.6.6.6:lock")).thenReturn(true);
        storedCode("123456");

        ApiException e = assertThrows(ApiException.class, () -> service.verify(EMAIL, "123456", "6.6.6.6"));

        assertEquals("TOO_MANY_ATTEMPTS", e.code());
    }

    @Test
    void distributedAttemptsOnOneCodeHitGlobalCapAndLockAddress() {
        storedCode("123456");
        when(ops.increment("vc:sc:" + EMAIL + ":" + SCOPE + ":att")).thenReturn(1L);
        when(ops.increment("vc:gatt:" + EMAIL)).thenReturn((long) VerificationService.GLOBAL_ATTEMPTS + 1);

        assertThrows(ApiException.class, () -> service.verify(EMAIL, "000000", SCOPE));

        verify(ops).set(eq("vc:lock:" + EMAIL), anyString(), any(java.time.Duration.class));
    }

    @Test
    void hourlyWrongTotalSurvivesCodeRefreshAndLocksAddress() {
        storedCode("123456");
        when(ops.increment("vc:att:" + EMAIL)).thenReturn(1L);
        when(ops.increment("vc:tot:" + EMAIL)).thenReturn((long) VerificationService.MAX_HOURLY_WRONG + 1);

        ApiException e = assertThrows(ApiException.class, () -> service.verify(EMAIL, "000000"));

        assertEquals("TOO_MANY_ATTEMPTS", e.code());
        verify(ops).set(eq("vc:lock:" + EMAIL), anyString(), any(java.time.Duration.class));
    }

    @Test
    void issueDoesNotUnlockWhenHourlyTotalAlreadyExceeded() {
        when(ops.setIfAbsent(eq("vc:cd:" + EMAIL), anyString(), any(java.time.Duration.class))).thenReturn(true);
        when(ops.get("vc:tot:" + EMAIL)).thenReturn(String.valueOf(VerificationService.MAX_HOURLY_WRONG + 1));

        service.issue(EMAIL, Lang.TR);

        // kod yenilemek sayaci/kilidi kaldirmaz: kilit yeniden yazilir
        verify(ops).set(eq("vc:lock:" + EMAIL), anyString(), any(java.time.Duration.class));
        verify(redis, never()).delete("vc:tot:" + EMAIL);
    }

    @Test
    void wrongResetTokenDoesNotBurnTheRealOne() {
        when(ops.get("prt:" + EMAIL)).thenReturn(Hashing.sha256("gercek"));

        assertFalse(service.consumeResetToken(EMAIL, "yanlis"));

        verify(redis, never()).delete("prt:" + EMAIL);
        verify(ops, never()).getAndDelete("prt:" + EMAIL);
    }

    @Test
    void correctResetTokenIsConsumedOnce() {
        when(ops.get("prt:" + EMAIL)).thenReturn(Hashing.sha256("gercek"));
        when(redis.delete("prt:" + EMAIL)).thenReturn(true, false);

        assertTrue(service.consumeResetToken(EMAIL, "gercek"));
        assertFalse(service.consumeResetToken(EMAIL, "gercek"));
    }
}
