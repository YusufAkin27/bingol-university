package edu.bingol.backend.crash;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Yeni (ya da yeniden acilan) cokme gruplari icin yoneticilere EN COK {@code app.crash.alert-interval-minutes} (60)
 * dakikada bir OZET bildirim. Alim yolu yalniz Redis sayacini artirir; bu gorev sayac doluysa ve son bildirimden
 * yeterli sure gectiyse tek bildirim gonderir (spam yok). Redis yoksa bildirim atlanir.
 */
@Component
public class CrashAlertService {

    private static final Logger log = LoggerFactory.getLogger(CrashAlertService.class);
    static final String PENDING_KEY = "crash:pending";
    static final String THROTTLE_KEY = "crash:alert:sent";

    private final StringRedisTemplate redis;
    private final SchedulerLock lock;
    private final UserRepository users;
    private final NotificationService notifications;
    private final int intervalMinutes;

    public CrashAlertService(StringRedisTemplate redis, SchedulerLock lock, UserRepository users,
                             NotificationService notifications,
                             @Value("${app.crash.alert-interval-minutes:60}") int intervalMinutes) {
        this.redis = redis;
        this.lock = lock;
        this.users = users;
        this.notifications = notifications;
        this.intervalMinutes = Math.max(1, intervalMinutes);
    }

    @Scheduled(fixedDelay = 120_000, initialDelay = 150_000)
    public void scheduled() {
        lock.tryRun("crash-alert", Duration.ofSeconds(60), this::flush);
    }

    /** Servis sozlesmesi: istisna sizdirmaz. @return bildirim gonderildiyse ozetlenen grup sayisi, aksi 0. */
    long flush() {
        try {
            String pending = redis.opsForValue().get(PENDING_KEY);
            if (pending == null || pending.isBlank()) {
                return 0;
            }
            Boolean first = redis.opsForValue().setIfAbsent(THROTTLE_KEY, "1", Duration.ofMinutes(intervalMinutes));
            if (!Boolean.TRUE.equals(first)) {
                return 0; // aralik dolmadi; sayac birikmeye devam eder
            }
            String taken = redis.opsForValue().getAndDelete(PENDING_KEY);
            long n = taken == null ? 0 : Long.parseLong(taken.strip());
            if (n <= 0) {
                return 0;
            }
            for (UserRepository.UserLang admin : users.audienceAdmins()) {
                try {
                    notifications.sendTemplated(admin.getId(), NotificationType.SYSTEM, "crash.alert",
                            Map.of("type", "CRASH_ALERT", "route", "/admin/crashes"), String.valueOf(n));
                } catch (RuntimeException e) {
                    log.warn("Cokme ozet bildirimi gonderilemedi: {}", e.toString());
                }
            }
            return n;
        } catch (RuntimeException e) {
            log.warn("Cokme bildirim gorevi basarisiz: {}", e.toString());
            return 0;
        }
    }
}
