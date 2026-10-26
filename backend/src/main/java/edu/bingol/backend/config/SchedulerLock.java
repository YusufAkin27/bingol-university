package edu.bingol.backend.config;

import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    public SchedulerLock(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** Kilit alinabilirse gorevi calistirir ve true doner; aksi halde (veya Redis hatasinda) false. Gorev hatasi yayilir. */
    public boolean tryRun(String name, Duration ttl, Runnable task) {
        String key = PREFIX + name;
        String token = UUID.randomUUID().toString();
        try {
            Boolean ok = redis.opsForValue().setIfAbsent(key, token, ttl);
            if (!Boolean.TRUE.equals(ok)) {
                log.debug("Zamanlayici kilidi baska ornekte: {}", name);
                return false;
            }
        } catch (RuntimeException e) {
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
