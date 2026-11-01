package edu.bingol.backend.config;

import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

/**
 * Cok ornekli calistirmada @Scheduled gorevlerinin ayni anda yalniz BIR ornekte kosmasi icin hafif dagitik kilit
 * (Redis SET NX PX + sahip belirteci ile guvenli birakma). Ek bagimlilik gerektirmez.
 *
 * <p>Kullanim: {@code lock.tryRun("news-sync", Duration.ofMinutes(30), this::syncAll);}
 *
 * <p>Kilit TTL ile sona erer (cokmus ornek kilidi sonsuza dek tutmaz): ttl, gorevin en uzun suresinden buyuk olmali.
 * Redis erisilemezse gorev ATLANIR (fail-closed: cift calisma, kacirilan calismadan kotudur; sonraki tetikte denenir).
 */
@Component
public class SchedulerLock {

    private static final Logger log = LoggerFactory.getLogger(SchedulerLock.class);
    private static final String PREFIX = "schedlock:";
    private static final DefaultRedisScript<Long> RELEASE = new DefaultRedisScript<>(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            Long.class);

    private final StringRedisTemplate redis;

    /** Tek ornekli kurulum: Redis yokken tryRunOrLocal gorevi yerelde calistirir. Varsayilan kapali (eski davranis). */
    @Value("${app.scheduling.single-instance:false}")
    private boolean singleInstance = false;

    public SchedulerLock(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** Kilit alinabilirse gorevi calistirir ve true doner; aksi halde (veya Redis hatasinda) false. Gorev hatasi yayilir. */
    public boolean tryRun(String name, Duration ttl, Runnable task) {
        return run(name, ttl, task, false);
    }

    /**
     * {@link #tryRun} gibi; tek farki: Redis ERISILEMEZSE ve {@code app.scheduling.single-instance=true} (tek ornekli
     * kurulum) ise gorevi kilitsiz YEREL calistirir (gece bakim isi Redis kesintisinde sessizce atlanmasin). Kilit baska
     * ornekte tutuluyorsa hicbir zaman calistirmaz. Varsayilan (false) tryRun ile ayni davranistir.
     */
    public boolean tryRunOrLocal(String name, Duration ttl, Runnable task) {
        return run(name, ttl, task, singleInstance);
    }

    private boolean run(String name, Duration ttl, Runnable task, boolean localFallback) {
        String key = PREFIX + name;
        String token = UUID.randomUUID().toString();
        try {
            Boolean ok = redis.opsForValue().setIfAbsent(key, token, ttl);
            if (!Boolean.TRUE.equals(ok)) {
                log.debug("Zamanlayici kilidi baska ornekte: {}", name);
                return false;
            }
        } catch (RuntimeException e) {
            if (localFallback) {
                log.warn("Zamanlayici kilidi alinamadi (Redis), tek ornek: gorev kilitsiz yerelde calisiyor: {} ({})",
                        name, e.getClass().getSimpleName());
                task.run();
                return true;
            }
            log.warn("Zamanlayici kilidi alinamadi (Redis), gorev atlandi: {} ({})", name, e.getClass().getSimpleName());
            return false;
        }
        try {
            task.run();
            return true;
        } finally {
            try {
                redis.execute(RELEASE, List.of(key), token);
            } catch (RuntimeException e) {
                log.warn("Zamanlayici kilidi birakilamadi, TTL ile sona erecek: {}", name);
            }
        }
    }
}
