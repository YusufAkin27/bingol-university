package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** Askiya alma: access token Redis anahtariyla aninda kapanir, refresh token'lar da silinir (revokeAll). */
class UserModerationSessionTest {

    private final UserRepository users = mock(UserRepository.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final SessionService sessions = mock(SessionService.class);
    private final UserModerationService service =
            new UserModerationService(users, redis, mock(NotificationService.class));

    private User user(Role role) {
        User u = new User();
        u.setId(9L);
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        when(users.findById(9L)).thenReturn(Optional.of(u));
        when(redis.opsForValue()).thenReturn(ops);
        return u;
    }

    @Test
    void suspendRevokesAllSessionsAfterWritingTheSuspendedMark() {
        User u = user(Role.USER);
        service.setSessions(sessions);

        service.suspend(9L, "spam");

        assertEquals(UserStatus.SUSPENDED, u.getStatus());
        InOrder order = inOrder(ops, sessions);
        order.verify(ops).set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 9L, "1");
        order.verify(sessions).revokeAll(9L);
    }

    @Test
    void suspendWithoutSessionServiceStillWorks() {
        user(Role.USER);

        service.suspend(9L, "spam");

        verify(ops).set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 9L, "1");
    }

    @Test
    void adminCannotBeSuspendedAndNothingIsRevoked() {
        user(Role.ADMIN);
        service.setSessions(sessions);

        org.junit.jupiter.api.Assertions.assertThrows(edu.bingol.backend.common.ApiException.class,
                () -> service.suspend(9L, "x"));

        verify(sessions, never()).revokeAll(9L);
    }
}
