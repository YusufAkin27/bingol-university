package edu.bingol.backend.observability;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/**
 * FIX-P09 (A08#3): Redis kesintisinde (en kritik bagimlilik) sistem uyarisi artik yutulmaz; onceki durum ve uyari
 * araligi bellek ici yedekle izlenir.
 */
class SystemAlertRedisDownTest {

    private SystemOverviewService overview;
    private StringRedisTemplate redis;
    private NotificationService notifications;
    private SystemAlertService alerts;
    private IndicatorStatus next = IndicatorStatus.CRIT;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        overview = mock(SystemOverviewService.class);
        redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.get(anyString())).thenThrow(new RuntimeException("redis down"));
        org.mockito.Mockito.doThrow(new RuntimeException("redis down")).when(ops).set(anyString(), anyString());
        when(ops.setIfAbsent(anyString(), anyString(), any(java.time.Duration.class))).thenThrow(new RuntimeException("redis down"));
        when(overview.cached()).thenAnswer(i -> new SystemOverviewService.Overview(Instant.now(), next,
                Map.of("redis", new Indicator(next, null, null, "x"))));
        UserRepository users = mock(UserRepository.class);
        UserRepository.UserLang admin = mock(UserRepository.UserLang.class);
        when(admin.getId()).thenReturn(1L);
        when(users.audienceAdmins()).thenReturn(List.of(admin));
        notifications = mock(NotificationService.class);
        ObservabilityProperties props = new ObservabilityProperties(1, 20, 10, 30, 80, 90, 3, 6, 1000, 120, 26, 32, true,
                "", 60, "", 80, 90);
        alerts = new SystemAlertService(overview, props, redis, mock(SchedulerLock.class), users, notifications,
                mock(MailService.class));
    }

    @Test
    void criticalTransitionStillAlertsWhenRedisIsDown() {
        alerts.check();
        verify(notifications, times(1)).sendTemplated(eq(1L), eq(NotificationType.SYSTEM), eq("obs.alert"), any(), anyString(),
                anyString());
    }

    @Test
    void staysQuietWhileStillCriticalAndWithinTheAlertInterval() {
        alerts.check();
        alerts.check(); // hala CRIT: gecis yok
        next = IndicatorStatus.OK;
        alerts.check();
        next = IndicatorStatus.CRIT;
        alerts.check(); // yeniden CRIT ama 60 dk araligi dolmadi (bellek ici)
        verify(notifications, times(1)).sendTemplated(eq(1L), eq(NotificationType.SYSTEM), eq("obs.alert"), any(), anyString(),
                anyString());
    }
}
