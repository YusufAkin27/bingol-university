package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
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
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** T-009: unsuspend yalniz askidaki hesapta; askiya alma isareti commit sonrasi. */
class UserModerationLifecycleTest {

    private final UserRepository users = mock(UserRepository.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final SessionService sessions = mock(SessionService.class);
    private final UserModerationService service = new UserModerationService(users, redis, notifications);

    UserModerationLifecycleTest() {
        service.setSessions(sessions);
        when(redis.opsForValue()).thenReturn(ops);
    }

    private User user(UserStatus status) {
        User u = new User();
        u.setId(9L);
        u.setRole(Role.USER);
        u.setStatus(status);
        when(users.findById(9L)).thenReturn(Optional.of(u));
        return u;
    }

    @Test
    void unsuspendOfADeletedAccountKeepsTheSuspendedMarkAndSendsNothing() {
        User u = user(UserStatus.DELETED);

        service.unsuspend(9L);

        assertEquals(UserStatus.DELETED, u.getStatus());
        verify(redis, never()).delete(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 9L);
        verify(notifications, never()).sendLocalized(any(), any(), anyString(), any(), any(), any());
    }

    @Test
    void unsuspendOfAnActiveAccountIsANoOp() {
        user(UserStatus.ACTIVE);

        service.unsuspend(9L);

        verify(redis, never()).delete(anyString());
        verify(notifications, never()).sendLocalized(any(), any(), anyString(), any(), any(), any());
    }

    @Test
    void unsuspendOfASuspendedAccountReactivatesClearsTheMarkAndNotifies() {
        User u = user(UserStatus.SUSPENDED);
        u.setSuspendedReason("spam");

        service.unsuspend(9L);

        assertEquals(UserStatus.ACTIVE, u.getStatus());
        verify(redis).delete(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 9L);
        verify(notifications).sendLocalized(eq(9L), any(), eq("notif.account.reactivated.title"), any(), any(), any());
    }

    @Test
    void suspendedMarkIsWrittenOnlyAfterTheTransactionCommits() {
        user(UserStatus.ACTIVE);
        TransactionSynchronizationManager.initSynchronization();
        try {
            service.suspend(9L, "spam");

            verify(ops, never()).set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 9L, "1");
            verify(sessions, never()).revokeAll(9L);
            TransactionSynchronizationManager.getSynchronizations().forEach(TransactionSynchronization::afterCommit);
            verify(ops).set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 9L, "1");
            verify(sessions).revokeAll(9L);
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void aRolledBackSuspensionLeavesNoRedisMark() {
        user(UserStatus.ACTIVE);
        TransactionSynchronizationManager.initSynchronization();
        try {
            service.suspend(9L, "spam");
            // islem geri alindi: afterCommit cagrilmaz
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }

        verify(ops, never()).set(anyString(), anyString());
        verify(sessions, never()).revokeAll(any());
    }
}
