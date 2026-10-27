package edu.bingol.backend.auth.token;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.JwtProperties;
import java.time.Duration;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class RefreshTokenServiceTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = mock(ValueOperations.class);
    @SuppressWarnings("unchecked")
    private final SetOperations<String, String> sets = mock(SetOperations.class);
    private final RefreshTokenService service = new RefreshTokenService(redis,
            new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));

    RefreshTokenServiceTest() {
        when(redis.opsForValue()).thenReturn(values);
        when(redis.opsForSet()).thenReturn(sets);
    }

    @Test
    void issueIndexesTokenHashPerUser() {
        String token = service.issue(7L);

        String hash = Hashing.sha256(token);
        verify(values).set(org.mockito.ArgumentMatchers.eq("rt:" + hash),
                org.mockito.ArgumentMatchers.eq("7:web"), any(Duration.class));
        verify(sets).add("rtu:7", hash);
    }

    @Test
    void consumeReturnsOwnerAndRemovesFromIndex() {
        when(values.getAndDelete("rt:" + Hashing.sha256("tok"))).thenReturn("7:web");

        assertEquals(7L, service.consume("tok"));
        verify(sets).remove("rtu:7", Hashing.sha256("tok"));
    }

    @Test
    void consumeUnknownTokenReturnsNull() {
        assertNull(service.consume("nope"));
    }

    @Test
    void revokeAllDeletesEveryTokenAndTheIndex() {
        when(sets.members("rtu:7")).thenReturn(Set.of("h1"));

        service.revokeAll(7L);

        verify(redis).delete(List.of("rt:h1"));
        verify(redis).delete("rtu:7");
        // iptal edilen token mezar tasi birakir
        verify(values).set(org.mockito.ArgumentMatchers.eq("rtx:h1"), org.mockito.ArgumentMatchers.eq("7"),
                any(Duration.class));
    }

    @Test
    void issueTagsClientAndConsumeReturnsIt() {
        service.issue(7L, "MOBILE");
        verify(values).set(org.mockito.ArgumentMatchers.startsWith("rt:"),
                org.mockito.ArgumentMatchers.eq("7:mobile"), any(Duration.class));

        when(values.getAndDelete("rt:" + Hashing.sha256("tok"))).thenReturn("7:mobile");
        RefreshTokenService.Session s = service.consumeSession("tok");
        assertEquals(7L, s.userId());
        assertEquals("mobile", s.client());
    }

    @Test
    void legacyTokenValueWithoutClientIsWeb() {
        when(values.getAndDelete("rt:" + Hashing.sha256("old"))).thenReturn("7");
        assertEquals("web", service.consumeSession("old").client());
    }

    @Test
    void revokeClientDeletesOnlyThatClientAndLeavesTombstone() {
        when(sets.members("rtu:7")).thenReturn(Set.of("m1", "w1", "gone"));
        when(values.get("rt:m1")).thenReturn("7:mobile");
        when(values.get("rt:w1")).thenReturn("7:web");
        when(values.get("rt:gone")).thenReturn(null);

        assertEquals(1, service.revokeClient(7L, "mobile"));

        verify(redis).delete("rt:m1");
        verify(redis, org.mockito.Mockito.never()).delete("rt:w1");
        verify(sets).remove("rtu:7", "m1");
        verify(sets).remove("rtu:7", "gone");
        verify(values).set(org.mockito.ArgumentMatchers.eq("rtx:m1"), org.mockito.ArgumentMatchers.eq("7"),
                any(Duration.class));
    }

    @Test
    void wasRevokedChecksTombstone() {
        when(redis.hasKey("rtx:" + Hashing.sha256("t"))).thenReturn(true);
        org.junit.jupiter.api.Assertions.assertTrue(service.wasRevoked("t"));
        org.junit.jupiter.api.Assertions.assertFalse(service.wasRevoked("other"));
    }

    @Test
    void revokeAllWithoutSessionsOnlyClearsIndex() {
        service.revokeAll(7L);

        verify(redis).delete("rtu:7");
        verify(redis, org.mockito.Mockito.never()).delete(org.mockito.ArgumentMatchers.<java.util.Collection<String>>any());
    }
}
