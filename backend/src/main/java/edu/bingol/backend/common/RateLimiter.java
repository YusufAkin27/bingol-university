package edu.bingol.backend.common;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

/**
 * Redis tabanli sabit pencere (fixed window) rate limit. Birden fazla sunucuda da ortak calisir.
 *
 * <p>Redis anahtar guvenligi (Redis 200 MB, kimliksiz yuzeyler ham girdiden anahtar kurar):
 * <ul>
 *   <li>Uzun anahtar ({@value #MAX_RAW_KEY} karakter ustu) SHA-256 ozetiyle kisaltilir: boylece bellek basina anahtar
 *       boyutu sabittir ve ham girdi (e-posta, baslik) anahtarda saklanmaz.</li>
 *   <li>Her anahtarin TTL'i vardir: INCR + (ilk INCR'de ya da TTL eksikse) PEXPIRE tek Lua betigidir; iki komut
 *       arasinda kesinti TTL'siz (kalici kilit) anahtar birakamaz ve istek basina tek Redis turu harcanir.</li>
 *   <li>Saatlik YENI anahtar butcesi: asildiginda yeni anahtar yaratilmaz, istek o oneke ait ORTAK taşma kovasina
 *       (limit x {@code app.ratelimit.overflow-multiplier}) sayilir. Butce ONEK BASINA sayilir
 *       ({@code app.ratelimit.new-key-budget-per-prefix}) ve ayrica tum onekler icin genel bir tavan vardir
 *       ({@code app.ratelimit.max-new-keys-per-hour}): tek gurultulu onek digerlerini ac birakamaz.</li>
 *   <li>Anahtar adlandirma kurali: son parcasi yalniz rakam ({@code \d{1,18}}) olan anahtar (ornek
 *       {@code acd:read:123}) dogrulanmis KULLANICI anahtaridir; sayisi kullanici sayisiyla sinirli oldugu icin butceden
 *       muaftir ve ortak kovaya dusmez. IPv6 benzeri anahtarlar ({@code ::} ya da ardisik hex parcalar) muaf sayilmaz.</li>
 * </ul>
 */
@Component
public class RateLimiter {

    private static final Logger log = LoggerFactory.getLogger(RateLimiter.class);

    /** Bu uzunlugu asan anahtarlar ozetlenir. */
    static final int MAX_RAW_KEY = 80;

    /** Metrik/uyari etiketi kardinalitesi ust siniri. */
    private static final int MAX_PREFIX_LABELS = 100;

    /** KEYS[1] sayac, ARGV[1] pencere (ms). Dondurur: yeni sayac degeri. */
    static final DefaultRedisScript<Long> INCR_TTL = new DefaultRedisScript<>(
            "local n = redis.call('INCR', KEYS[1])\n"
                    + "if n == 1 or redis.call('PTTL', KEYS[1]) < 0 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end\n"
                    + "return n",
            Long.class);

    /**
     * KEYS[1] onek butcesi, KEYS[2] genel butce; ARGV[1] TTL (ms), ARGV[2] onek siniri, ARGV[3] genel sinir
     * (0 = sinirsiz). Dondurur: 1 butce asildi, 0 asilmadi. Onek butcesi asilirsa genel sayac artmaz.
     */
    static final DefaultRedisScript<Long> NEW_KEY_BUDGET = new DefaultRedisScript<>(
            "local p = redis.call('INCR', KEYS[1])\n"
                    + "if p == 1 or redis.call('PTTL', KEYS[1]) < 0 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end\n"
                    + "if tonumber(ARGV[2]) > 0 and p > tonumber(ARGV[2]) then return 1 end\n"
                    + "local g = redis.call('INCR', KEYS[2])\n"
                    + "if g == 1 or redis.call('PTTL', KEYS[2]) < 0 then redis.call('PEXPIRE', KEYS[2], ARGV[1]) end\n"
                    + "if tonumber(ARGV[3]) > 0 and g > tonumber(ARGV[3]) then return 1 end\n"
                    + "return 0",
            Long.class);

    private final StringRedisTemplate redis;

    /** Tum onekler icin saatlik yeni anahtar tavani (eski ayar adi korunur); <=0 = sinirsiz. */
    @Value("${app.ratelimit.max-new-keys-per-hour:200000}")
    private long newKeyBudget = 200_000;
    /** Onek basina saatlik yeni anahtar butcesi; <=0 = sinirsiz. */
    @Value("${app.ratelimit.new-key-budget-per-prefix:50000}")
    private long newKeyBudgetPerPrefix = 50_000;
    @Value("${app.ratelimit.overflow-multiplier:50}")
    private int overflowMultiplier = 50;

    /** Redis devre kesici (T-003); yoksa (birim testleri) Redis hatasi aynen yukari atilir. */
    private RedisBreaker breaker;
    private MeterRegistry meters;
    private final ConcurrentHashMap<String, Counter> overflowCounters = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Long> warnedHour = new ConcurrentHashMap<>();

    public RateLimiter(StringRedisTemplate redis) {
        this.redis = redis;
    }

    @Autowired(required = false)
    void setBreaker(RedisBreaker breaker) {
        this.breaker = breaker;
    }

    @Autowired(required = false)
    void setMeterRegistry(MeterRegistry meters) {
        this.meters = meters;
    }

    /**
     * `key` icin pencere icinde `max` istegi asarsa 429 firlatir. Redis kesikse (devre kesici) Redis'e gitmeden
     * 503 REDIS_UNAVAILABLE doner; kayan pencerede esik kadar Redis hatasi devreyi acar.
     */
    public void check(String key, int max, Duration window) {
        if (breaker == null) {
            doCheck(key, max, window);
            return;
        }
        if (breaker.isOpen()) {
            throw new RedisUnavailableException(breaker.retryAfterSeconds());
        }
        try {
            doCheck(key, max, window);
        } catch (RuntimeException e) {
            if (RedisBreaker.isRedisFailure(e)) {
                breaker.trip(e);
                throw new RedisUnavailableException(breaker.retryAfterSeconds());
            }
            if (e instanceof RateLimitedException) {
                breaker.recordSuccess(); // Redis cevap verdi (limit asimi is kurali)
            }
            throw e;
        }
        breaker.recordSuccess();
    }

    private void doCheck(String key, int max, Duration window) {
        String prefix = prefixOf(key);
        long windowMs = Math.max(1, window.toMillis());
        String k = "rl:" + safeKey(key);
        Long n = incr(k, windowMs);
        if (n == null) {
            return;
        }
        if (n == 1 && !isUserKey(key) && overBudget(prefix)) {
            // Yeni anahtar butcesi doldu: bu anahtari bellekten at, ortak tasma kovasina say
            redis.delete(k);
            onOverflow(prefix);
            k = "rl:ovf:" + prefix;
            n = incr(k, windowMs);
            if (n == null) {
                return;
            }
            max = (int) Math.min(Integer.MAX_VALUE, (long) max * Math.max(1, overflowMultiplier));
        }
        if (n > max) {
            Long ttl = redis.getExpire(k);
            throw new RateLimitedException(ttl == null || ttl < 0 ? Math.max(1, window.toSeconds()) : ttl);
        }
    }

    private Long incr(String key, long windowMs) {
        return redis.execute(INCR_TTL, List.of(key), String.valueOf(windowMs));
    }

    /** Uzun anahtari sabit boyuta indirir (onek + ozet); kisa anahtar aynen kalir. */
    static String safeKey(String key) {
        if (key == null) {
            return "null";
        }
        if (key.length() <= MAX_RAW_KEY) {
            return key;
        }
        return key.substring(0, 32) + "#" + Hashing.sha256(key).substring(0, 32);
    }

    /** Anahtarin ilk bolumu (login, forgot, ...): tasma kovasinin adi. */
    static String prefixOf(String key) {
        if (key == null) {
            return "null";
        }
        int i = key.indexOf(':');
        String p = i > 0 ? key.substring(0, i) : key;
        return p.length() > 24 ? p.substring(0, 24) : p;
    }

    /**
     * Dogrulanmis kullanici anahtari mi? Son parca yalniz rakam ({@code \d{1,18}}) ve anahtar IPv6 benzeri degil.
     * IPv6 {@code limitKey} ciktisi ({@code v6:...::/64}) ya da ham IPv6 son parcasi rakam olsa bile muaf OLMAZ.
     */
    static boolean isUserKey(String key) {
        if (key == null) {
            return false;
        }
        int i = key.lastIndexOf(':');
        if (i <= 0 || i == key.length() - 1) {
            return false;
        }
        int len = key.length() - i - 1;
        if (len > 18) {
            return false;
        }
        for (int j = i + 1; j < key.length(); j++) {
            char c = key.charAt(j);
            if (c < '0' || c > '9') {
                return false;
            }
        }
        if (key.contains("::")) {
            return false;
        }
        // IPv6 benzeri: sondan geriye ardisik 3+ parca 1-4 karakterli hex
        String[] parts = key.split(":", -1);
        int run = 0;
        for (int p = parts.length - 1; p >= 0; p--) {
            if (isHexGroup(parts[p])) {
                run++;
            } else {
                break;
            }
        }
        return run < 3;
    }

    private static boolean isHexGroup(String s) {
        if (s.isEmpty() || s.length() > 4) {
            return false;
        }
        for (int i = 0; i < s.length(); i++) {
            if (Character.digit(s.charAt(i), 16) < 0) {
                return false;
            }
        }
        return true;
    }

    /** Bu saatte olusturulan yeni anahtar sayisini artirir (onek + genel); butce asildiysa true. */
    private boolean overBudget(String prefix) {
        if (newKeyBudgetPerPrefix <= 0 && newKeyBudget <= 0) {
            return false;
        }
        long hour = Instant.now().getEpochSecond() / 3600;
        Long over = redis.execute(NEW_KEY_BUDGET, List.of("rlnew:" + prefix + ":" + hour, "rlnew:" + hour),
                String.valueOf(Duration.ofHours(2).toMillis()), String.valueOf(newKeyBudgetPerPrefix),
                String.valueOf(newKeyBudget));
        return over != null && over == 1L;
    }

    /** Butce asimi: Micrometer sayaci + onek basina saatte tek WARN. */
    private void onOverflow(String prefix) {
        String label = overflowCounters.containsKey(prefix) || overflowCounters.size() < MAX_PREFIX_LABELS ? prefix : "other";
        if (meters != null) {
            overflowCounters.computeIfAbsent(label,
                    p -> Counter.builder("bu.ratelimit.overflow").tag("prefix", p).register(meters)).increment();
        }
        long hour = Instant.now().getEpochSecond() / 3600;
        if (warnedHour.size() < MAX_PREFIX_LABELS || warnedHour.containsKey(label)) {
            Long prev = warnedHour.put(label, hour);
            if (prev == null || prev != hour) {
                log.warn("Rate limit yeni anahtar butcesi doldu, ortak tasma kovasi kullaniliyor: onek={}", label);
            }
        }
    }
}
