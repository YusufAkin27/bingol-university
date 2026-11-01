package edu.bingol.backend.crash;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

/**
 * Cokme firtinasi freni (FIX-P09 / A08#1): ayni hata imzasi dakikada {@code app.crash.group-per-minute} (30) kez
 * veritabanina yazilir; fazlasi YALNIZ Redis'te sayilir ({@code crash:overflow} hash'i, alan = imza|surum|platform)
 * ve {@link CrashService#flushOverflow} ile dakikada bir {@code event_count}/surum dagilimina toplu eklenir.
 * Boylece hatali bir surum acilista cokunce tek {@code crash_group} satiri uzerinde istek kuyrugu olusmaz.
 * Redis erisilemezse {@link #allow} true doner (fail-open): yazma yine de {@link CrashService}'in es zamanlilik
 * kapisi (Semaphore) ile sinirlidir.
 */
@Component
public class CrashThrottle {

    private static final Logger log = LoggerFactory.getLogger(CrashThrottle.class);
    static final String OVERFLOW_KEY = "crash:overflow";
    private static final String RATE_PREFIX = "crash:rl:";
    private static final DefaultRedisScript<Long> HIT = new DefaultRedisScript<>(
            "local n = redis.call('INCR', KEYS[1]) if n == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end return n",
            Long.class);
    /** Alani atomik al-ve-sil (iki ornek ayni degeri iki kez eklemesin). */
    private static final DefaultRedisScript<Long> TAKE = new DefaultRedisScript<>(
            "local v = redis.call('HGET', KEYS[1], ARGV[1]) if v then redis.call('HDEL', KEYS[1], ARGV[1]) "
                    + "return tonumber(v) end return 0",
            Long.class);

    private final StringRedisTemplate redis;
    private final int perMinute;

    public CrashThrottle(StringRedisTemplate redis, @Value("${app.crash.group-per-minute:30}") int perMinute) {
        this.redis = redis;
        this.perMinute = Math.max(1, perMinute);
    }

    /** @return true: bu olay veritabanina yazilmali; false: esik asildi, {@link #countOverflow} ile sayilmali. */
    public boolean allow(String signature, Instant now) {
        try {
            String key = RATE_PREFIX + signature + ":" + (now.getEpochSecond() / 60);
            Long n = redis.execute(HIT, List.of(key), "120");
            return n == null || n <= perMinute;
        } catch (RuntimeException e) {
            log.debug("Cokme freni Redis hatasi (fail-open): {}", e.toString());
            return true;
        }
    }

    /** Esik ustu olayi sayar. @return false: sayilamadi (Redis yok); olay sessizce dusulur. */
    public boolean countOverflow(String signature, String version, String platform) {
        try {
            redis.opsForHash().increment(OVERFLOW_KEY, field(signature, version, platform), 1);
            redis.expire(OVERFLOW_KEY, Duration.ofDays(1));
            return true;
        } catch (RuntimeException e) {
            log.debug("Cokme tasma sayaci yazilamadi: {}", e.toString());
            return false;
        }
    }

    /** Birikmis tasma sayaclarini (en cok {@code max} alan) alir ve Redis'ten siler. alan -> adet. */
    public Map<String, Long> takeOverflow(int max) {
        Map<String, Long> out = new HashMap<>();
        try {
            List<Object> fields = new ArrayList<>(redis.opsForHash().keys(OVERFLOW_KEY));
            for (Object f : fields) {
                if (out.size() >= max) {
                    break;
                }
                Long n = redis.execute(TAKE, List.of(OVERFLOW_KEY), String.valueOf(f));
                if (n != null && n > 0) {
                    out.put(String.valueOf(f), n);
                }
            }
        } catch (RuntimeException e) {
            log.debug("Cokme tasma sayaci okunamadi: {}", e.toString());
        }
        return out;
    }

    /** Islenemeyen sayaci geri koyar (sonraki turda yeniden denenir). */
    public void restore(String field, long n) {
        try {
            redis.opsForHash().increment(OVERFLOW_KEY, field, n);
        } catch (RuntimeException e) {
            log.debug("Cokme tasma sayaci geri konamadi: {}", e.toString());
        }
    }

    static String field(String signature, String version, String platform) {
        return signature + "|" + version + "|" + platform;
    }

    /** {imza, surum, platform}; bozuk alan icin null. */
    static String[] parse(String field) {
        String[] p = field.split("\\|", 3);
        return p.length == 3 ? p : null;
    }
}
