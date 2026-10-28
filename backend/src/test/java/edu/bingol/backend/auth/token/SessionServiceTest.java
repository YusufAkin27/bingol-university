package edu.bingol.backend.auth.token;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class SessionServiceTest {

    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtService jwt = mock(JwtService.class);
    private final Clock clock = Clock.fixed(Instant.ofEpochMilli(1_700_000_000_500L), ZoneOffset.UTC);
    private final SessionService sessions =
            new SessionService(refresh, redis, jwt, clock, mock(ApplicationEventPublisher.class));

    SessionServiceTest() {
        when(redis.opsForValue()).thenReturn(ops);
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
    }

    @Test
    void revokeAllWritesTheMarkBeforeSnapshottingRefreshTokens() {
        // refresh ile yaris: isaret ONCE yazilmali ki arada uretilen yeni token'in oturum zamani isaretten eski kalsin
        sessions.revokeAll(7L);

        InOrder order = inOrder(ops, refresh);
        order.verify(ops).set(eq(JwtAuthFilter.PASSWORD_CHANGED_KEY_PREFIX + 7L), eq("1700000000500"), any(Duration.class));
        order.verify(refresh).revokeAll(7L);
    }

    @Test
    void sessionStartedBeforeTheRevocationIsRevokedLaterOneIsNot() {
        when(ops.get(JwtAuthFilter.PASSWORD_CHANGED_KEY_PREFIX + 7L)).thenReturn("1700000000500");

        assertTrue(sessions.isRevokedSince(7L, "web", 1_700_000_000_100L));
        assertTrue(sessions.isRevokedSince(7L, "web", 1_700_000_000_500L));
        assertFalse(sessions.isRevokedSince(7L, "web", 1_700_000_000_501L));
        // eski token (oturum zamani bilinmiyor) etkilenmez
        assertFalse(sessions.isRevokedSince(7L, "web", 0L));
    }

    @Test
    void mobileSingleDeviceMarkOnlyAppliesToMobileSessions() {
        when(ops.get(JwtAuthFilter.MOBILE_REVOKED_KEY_PREFIX + 7L)).thenReturn("1700000000500");

        assertTrue(sessions.isRevokedSince(7L, "mobile", 1_700_000_000_100L));
        assertFalse(sessions.isRevokedSince(7L, "web", 1_700_000_000_100L));
        assertFalse(sessions.isRevokedSince(7L, "mobile", 1_700_000_000_900L));
        org.mockito.Mockito.verify(ops, org.mockito.Mockito.never()).set(anyString(), anyString(), any(Duration.class));
    }
}
