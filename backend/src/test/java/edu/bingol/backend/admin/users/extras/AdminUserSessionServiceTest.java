package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.users.extras.UserExtrasDtos.SessionList;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class AdminUserSessionServiceTest {

    private static final String H1 = "aaaaaaaaaaaaaaaa1111111111111111111111111111111111111111aaaa";
    private static final String H2 = "bbbbbbbbbbbbbbbb2222222222222222222222222222222222222222bbbb";

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> values = mock(ValueOperations.class);
    @SuppressWarnings("unchecked")
    private final SetOperations<String, String> sets = mock(SetOperations.class);
    private final UserRepository users = mock(UserRepository.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-28T10:00:00Z"), ZoneOffset.UTC);
    private final AdminUserSessionService service =
            new AdminUserSessionService(redis, users, new JwtProperties("s", 15, 90), clock);

    AdminUserSessionServiceTest() {
        when(redis.opsForValue()).thenReturn(values);
        when(redis.opsForSet()).thenReturn(sets);
        when(users.findById(5L)).thenReturn(Optional.of(new User()));
        when(sets.members("rtu:5")).thenReturn(Set.of(H1, H2));
        when(values.get("rt:" + H1)).thenReturn("5:mobile:1761600000000");
        when(values.get("rt:" + H2)).thenReturn("5:web:1761700000000");
        when(redis.getExpire(eq("rt:" + H1), eq(TimeUnit.SECONDS))).thenReturn(3600L);
        when(redis.getExpire(eq("rt:" + H2), eq(TimeUnit.SECONDS))).thenReturn(-1L);
    }

    @Test
    void listsSessionsWithoutExposingFullHashes() {
        SessionList l = service.list(5L);

        assertEquals(2, l.total());
        // en yeni giris once
        assertEquals("web", l.items().get(0).client());
        assertEquals("bbbbbbbbbbbbbbbb", l.items().get(0).id());
        assertNull(l.items().get(0).expiresAt());
        assertEquals("mobile", l.items().get(1).client());
        assertEquals("2026-10-28T11:00:00Z", l.items().get(1).expiresAt());
        for (var s : l.items()) {
            assertEquals(16, s.id().length());
            assertFalse(s.toString().contains("1111111111"));
        }
    }

    @Test
    void staleSetMembersAreSkipped() {
        when(values.get("rt:" + H2)).thenReturn(null);
        assertEquals(1, service.list(5L).total());
    }

    @Test
    void revokeDeletesTokenSetEntryAndWritesTombstone() {
        service.revoke(5L, "aaaaaaaaaaaaaaaa");

        verify(redis).delete("rt:" + H1);
        verify(sets).remove("rtu:5", H1);
        verify(values).set(eq("rtx:" + H1), eq("5"), eq(Duration.ofDays(90)));
        verify(redis, never()).delete("rt:" + H2);
    }

    @Test
    void unknownOrMalformedSessionIdIs404() {
        for (String bad : new String[] {"cccccccccccccccc", "AAAAAAAAAAAAAAAA", "short", "../..", null}) {
            ApiException e = assertThrows(ApiException.class, () -> service.revoke(5L, bad));
            assertEquals("SESSION_NOT_FOUND", e.code());
            assertEquals(404, e.status().value());
        }
        verify(redis, never()).delete(anyString());
        assertTrue(true);
    }

    @Test
    void unknownUserIs404() {
        ApiException e = assertThrows(ApiException.class, () -> service.list(99L));
        assertEquals("USER_NOT_FOUND", e.code());
        verify(sets, never()).members(any());
    }
}
