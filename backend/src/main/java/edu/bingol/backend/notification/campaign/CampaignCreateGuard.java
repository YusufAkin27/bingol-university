package edu.bingol.backend.notification.campaign;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

/**
 * Kampanya olusturmada "ayni icerik + kitle" icin ATOMIK kisa sureli kilit (A14-09). Eski kontrol "say, sonra kaydet"
 * oldugundan iki eszamanli istek ikisi de 0 sayip iki kampanya olusturuyordu. Kilit, sayma + kayit boyunca tutulur:
 * ikinci eszamanli istek beklemeden 409 CAMPAIGN_DUPLICATE alir; birinci bitince (kayit commit edildi) sirali tekrarlar
 * zaten {@code countRecentDuplicates} ile yakalanir.
 *
 * <p>Iki katman: (1) JVM ici {@code ConcurrentHashMap.putIfAbsent} (tek ornek, Redis'siz de calisir); (2) Redis
 * {@code SET NX PX} (cok ornek; {@code app.campaign.redis-lock=true}). Redis hatasinda yalniz JVM katmani kalir (yonetici
 * islemi Redis yuzunden bloke olmaz; kilit zaten kisa omurlu bir korumadir).
 */
@Component
public class CampaignCreateGuard {

    private static final Logger log = LoggerFactory.getLogger(CampaignCreateGuard.class);
    /** Kilit en fazla bu kadar tutulur (kayit cokerse sonsuza dek kalmasin). */
    static final Duration TTL = Duration.ofSeconds(30);
    private static final String PREFIX = "campcreate:";
    private static final DefaultRedisScript<Long> RELEASE = new DefaultRedisScript<>(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            Long.class);

    private final ConcurrentHashMap<String, Long> local = new ConcurrentHashMap<>();
    private StringRedisTemplate redis;
    private final boolean redisEnabled;

    public CampaignCreateGuard(@Value("${app.campaign.redis-lock:false}") boolean redisEnabled) {
        this.redisEnabled = redisEnabled;
    }

    @Autowired(required = false)
    void setRedis(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** Kilit alindiysa birakma tutamagi, baska bir istek tutuyorsa {@code null}. try/finally ile {@code release}. */
    public Lock tryAcquire(Long adminId, String title, String body, Object audienceType, String audienceValue) {
        String key = PREFIX + adminId + ":" + digest(title, body, String.valueOf(audienceType),
                audienceValue == null ? "" : audienceValue);
        long now = System.currentTimeMillis();
        long expiry = now + TTL.toMillis();
        // Suresi dolmus yerel kilidi (cokmus iplik) temizle, sonra atomik al
        local.computeIfPresent(key, (k, v) -> v < now ? null : v);
        if (local.putIfAbsent(key, expiry) != null) {
            return null;
        }
        String token = UUID.randomUUID().toString();
        boolean remote = false;
        if (redisEnabled && redis != null) {
            try {
                Boolean ok = redis.opsForValue().setIfAbsent(key, token, TTL);
                if (!Boolean.TRUE.equals(ok)) {
                    local.remove(key);
                    return null;
                }
                remote = true;
            } catch (RuntimeException e) {
                log.warn("Kampanya kilidi Redis'te alinamadi, yalniz yerel kilit kullanildi ({})",
                        e.getClass().getSimpleName());
            }
        }
        return new Lock(key, token, remote);
    }

    public final class Lock implements AutoCloseable {
        private final String key;
        private final String token;
        private final boolean remote;

        private Lock(String key, String token, boolean remote) {
            this.key = key;
            this.token = token;
            this.remote = remote;
        }

        @Override
        public void close() {
            local.remove(key);
            if (remote && redis != null) {
                try {
                    redis.execute(RELEASE, List.of(key), token);
                } catch (RuntimeException e) {
                    log.warn("Kampanya kilidi Redis'te birakilamadi, TTL ile sona erecek");
                }
            }
        }
    }

    private static String digest(String... parts) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            for (String p : parts) {
                md.update(p.getBytes(StandardCharsets.UTF_8));
                md.update((byte) 0);
            }
            return HexFormat.of().formatHex(md.digest());
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e); // SHA-256 her JVM'de vardir
        }
    }
}
