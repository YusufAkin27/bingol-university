package edu.bingol.backend.analytics;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Kimlikli isteklerde son gorulme ve gunluk aktiflik kaydi. Istek yolunu yavaslatmamak icin:
 * kullanici basina Redis kapisi (5 dk) ve veritabani yazimi sinirli kuyruklu arka plan is parcacigi.
 * Her hata yutulur: takip asla istegi bozmaz. Kuyruk dolarsa yazim atlanir (sonraki istekte tekrar denenir).
 */
@Component
public class ActivityTracker {

    private static final Logger log = LoggerFactory.getLogger(ActivityTracker.class);
    static final Duration SEEN_INTERVAL = Duration.ofMinutes(15); // app_user satiri guncellemesi (indeksli kolon, HOT degil) 3 kat azalir
    private static final Duration DAY_KEY_TTL = Duration.ofHours(30);

    private final StringRedisTemplate redis;
    private final ActivityRepository repo;
    private final Clock clock;
    private final ThreadPoolExecutor executor = new ThreadPoolExecutor(1, 2, 30, TimeUnit.SECONDS,
            new ArrayBlockingQueue<>(1000), r -> {
                Thread t = new Thread(r, "activity-tracker");
                t.setDaemon(true);
                return t;
            }, new ThreadPoolExecutor.DiscardPolicy());

    public ActivityTracker(StringRedisTemplate redis, ActivityRepository repo, Clock clock) {
        this.redis = redis;
        this.repo = repo;
        this.clock = clock;
    }

    /** Dogrulanmis bir kullanicinin istegi geldi. Genelde tek bir Redis cagrisiyla biter. */
    public void touch(Long userId) {
        try {
            if (!Boolean.TRUE.equals(redis.opsForValue().setIfAbsent("seen:" + userId, "1", SEEN_INTERVAL))) {
                return;
            }
            LocalDate day = DateRange.today(clock);
            boolean firstToday = Boolean.TRUE.equals(
                    redis.opsForValue().setIfAbsent("act:" + userId + ":" + day, "1", DAY_KEY_TTL));
            executor.execute(() -> write(userId, day, firstToday));
        } catch (RuntimeException e) {
            log.debug("Aktiflik kaydi atlandi: {}", e.toString());
        }
    }

    private void write(Long userId, LocalDate day, boolean firstToday) {
        try {
            repo.touchLastSeen(userId);
            if (firstToday) {
                repo.markActive(userId, day);
            }
        } catch (RuntimeException e) {
            log.debug("Aktiflik yazimi basarisiz: {}", e.toString());
        }
    }
}
