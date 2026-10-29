package edu.bingol.backend.crash;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** Yoneticiye cokme ozet bildirimi: en cok aralik basina bir, spam yok. */
class CrashAlertServiceTest {

    private StringRedisTemplate redis;
    private ValueOperations<String, String> ops;
    private UserRepository users;
    private NotificationService notifications;
    private CrashAlertService service;

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        redis = mock(StringRedisTemplate.class);
        ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        users = mock(UserRepository.class);
        notifications = mock(NotificationService.class);
        UserRepository.UserLang a1 = mock(UserRepository.UserLang.class);
        UserRepository.UserLang a2 = mock(UserRepository.UserLang.class);
        when(a1.getId()).thenReturn(1L);
        when(a2.getId()).thenReturn(2L);
        when(users.audienceAdmins()).thenReturn(List.of(a1, a2));
        service = new CrashAlertService(redis, mock(SchedulerLock.class), users, notifications, 60);
    }

    @Test
    void sendsOneDigestToEveryAdminWhenPendingAndIntervalElapsed() {
        when(ops.get(CrashAlertService.PENDING_KEY)).thenReturn("3");
        when(ops.setIfAbsent(eq(CrashAlertService.THROTTLE_KEY), any(), any(Duration.class))).thenReturn(true);
        when(ops.getAndDelete(CrashAlertService.PENDING_KEY)).thenReturn("3");

        assertThat(service.flush()).isEqualTo(3);

        verify(notifications, times(2)).sendTemplated(anyLong(), eq(NotificationType.SYSTEM), eq("crash.alert"),
                anyMap(), eq("3"));
    }

    @Test
    void doesNothingWithinIntervalAndKeepsCounter() {
        when(ops.get(CrashAlertService.PENDING_KEY)).thenReturn("2");
        when(ops.setIfAbsent(eq(CrashAlertService.THROTTLE_KEY), any(), any(Duration.class))).thenReturn(false);

        assertThat(service.flush()).isZero();

        verify(ops, never()).getAndDelete(any());
        verify(notifications, never()).sendTemplated(anyLong(), any(), any(), anyMap(), any());
    }

    @Test
    void doesNothingWhenNothingPending() {
        when(ops.get(CrashAlertService.PENDING_KEY)).thenReturn(null);

        assertThat(service.flush()).isZero();

        verify(ops, never()).setIfAbsent(any(), any(), any(Duration.class));
        verify(notifications, never()).sendTemplated(anyLong(), any(), any(), anyMap(), any());
    }

    @Test
    void neverThrowsWhenRedisFails() {
        when(ops.get(CrashAlertService.PENDING_KEY)).thenThrow(new IllegalStateException("redis down"));

        assertThat(service.flush()).isZero();
    }
}
