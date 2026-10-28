package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class AdminUserServiceTest {

    private final AdminUserRepository repo = mock(AdminUserRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final ProfileService profiles = mock(ProfileService.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtService jwt = mock(JwtService.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-23T12:00:00Z"), ZoneOffset.UTC);
    private final AdminUserService service = new AdminUserService(repo, users, profiles, redis, jwt, clock);

    AdminUserServiceTest() {
        when(redis.opsForValue()).thenReturn(ops);
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
    }

    private User user(long id, Role role) {
        User u = new User();
        u.setId(id);
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    @Test
    void cannotDemoteSelf() {
        user(1L, Role.ADMIN);

        ApiException e = assertThrows(ApiException.class, () -> service.changeRole(1L, 1L, Role.USER));

        assertEquals("CANNOT_MODIFY_SELF", e.code());
        assertEquals(400, e.status().value());
        verify(users, never()).save(any());
    }

    @Test
    void lastAdminCannotBeDemoted() {
        user(2L, Role.ADMIN);
        when(users.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE)).thenReturn(1L);

        ApiException e = assertThrows(ApiException.class, () -> service.changeRole(1L, 2L, Role.USER));

        assertEquals("LAST_ADMIN", e.code());
        assertEquals(409, e.status().value());
        verify(users, never()).save(any());
    }

    @Test
    void demoteWithAnotherAdminWorksAndMarksOldTokens() {
        User target = user(2L, Role.ADMIN);
        when(users.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE)).thenReturn(2L);

        service.changeRole(1L, 2L, Role.USER);

        assertEquals(Role.USER, target.getRole());
        verify(users).lockAdminIds();
        verify(users).save(target);
        // Eski JWT'yi reddettiren isaret: degisim zamani (epoch ms), access token omru + 1 dk
        verify(ops).set(JwtAuthFilter.ROLE_CHANGED_KEY_PREFIX + 2L,
                String.valueOf(Instant.parse("2026-10-23T12:00:00Z").toEpochMilli()), Duration.ofMinutes(16));
    }

    @Test
    void promoteDoesNotNeedAdminCountCheckButMarksToken() {
        User target = user(3L, Role.USER);

        service.changeRole(1L, 3L, Role.ADMIN);

        assertEquals(Role.ADMIN, target.getRole());
        verify(users, never()).lockAdminIds();
        verify(ops).set(eq(JwtAuthFilter.ROLE_CHANGED_KEY_PREFIX + 3L), anyString(), any(Duration.class));
    }

    @Test
    void sameRoleIsNoOp() {
        user(3L, Role.USER);

        service.changeRole(1L, 3L, Role.USER);

        verify(users, never()).save(any());
        verify(ops, never()).set(anyString(), anyString(), any(Duration.class));
    }

    @Test
    void roleMarkIsWrittenOnlyAfterCommitWithMillisecondPrecision() {
        user(3L, Role.USER);
        org.springframework.transaction.support.TransactionSynchronizationManager.initSynchronization();
        try {
            service.changeRole(1L, 3L, Role.ADMIN);

            // commit'ten once isaret yok: erken yazilirsa commit oncesi refresh eski rolle token alirdi
            verify(ops, never()).set(eq(JwtAuthFilter.ROLE_CHANGED_KEY_PREFIX + 3L), anyString(), any(Duration.class));
            for (var s : org.springframework.transaction.support.TransactionSynchronizationManager.getSynchronizations()) {
                s.afterCommit();
            }
            verify(ops).set(JwtAuthFilter.ROLE_CHANGED_KEY_PREFIX + 3L,
                    String.valueOf(Instant.parse("2026-10-23T12:00:00Z").toEpochMilli()), Duration.ofMinutes(16));
        } finally {
            org.springframework.transaction.support.TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void deleteAlsoRevokesRefreshSessions() {
        user(4L, Role.USER);
        var sessions = mock(edu.bingol.backend.auth.token.SessionService.class);
        service.setSessions(sessions);

        service.delete(1L, 4L);

        verify(sessions).revokeAll(4L);
    }

    @Test
    void basicAuthAdminWithoutIdCanChangeRoles() {
        User target = user(3L, Role.USER);

        service.changeRole(null, 3L, Role.ADMIN);

        assertEquals(Role.ADMIN, target.getRole());
    }

    @Test
    void unknownOrDeletedUserIs404() {
        when(users.findById(9L)).thenReturn(Optional.empty());
        assertEquals(404, assertThrows(ApiException.class, () -> service.changeRole(1L, 9L, Role.ADMIN)).status().value());

        User gone = user(8L, Role.USER);
        gone.setStatus(UserStatus.DELETED);
        assertEquals(404, assertThrows(ApiException.class, () -> service.changeRole(1L, 8L, Role.ADMIN)).status().value());
    }

    @Test
    void cannotDeleteSelf() {
        ApiException e = assertThrows(ApiException.class, () -> service.delete(1L, 1L));

        assertEquals("CANNOT_MODIFY_SELF", e.code());
        verify(profiles, never()).anonymizeAccount(any());
    }

    @Test
    void lastAdminCannotBeDeleted() {
        user(2L, Role.ADMIN);
        when(users.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE)).thenReturn(1L);

        assertEquals("LAST_ADMIN", assertThrows(ApiException.class, () -> service.delete(1L, 2L)).code());
        verify(profiles, never()).anonymizeAccount(any());
    }

    @Test
    void deleteAnonymizesAndBlocksExistingTokens() {
        user(5L, Role.USER);

        service.delete(1L, 5L);

        verify(profiles).anonymizeAccount(5L);
        verify(ops).set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 5L, "1");
    }
}
