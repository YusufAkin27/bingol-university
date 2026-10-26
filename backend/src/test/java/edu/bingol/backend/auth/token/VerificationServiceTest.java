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

    VerificationServiceTest() {
        when(redis.opsForValue()).thenReturn(ops);
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
}
