package edu.bingol.backend.auth.token;

import java.time.Duration;
import java.util.Map;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Dogrulanmamis kayit verisi (sifre ozeti, ad, dil) e-posta dogrulanana kadar Redis'te tutulur; veritabaninda
 * hesap satiri olusmaz. Boylece baskasinin e-postasiyla onceden kayit acip sifreyi "on ele gecirme" mumkun olmaz.
 */
@Component
public class PendingRegistrationStore {

    public record Pending(String passwordHash, String displayName, String language) {}

    private static final Duration TTL = Duration.ofHours(1);

    private final StringRedisTemplate redis;

    public PendingRegistrationStore(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void save(String email, Pending p) {
        redis.opsForHash().putAll(key(email),
                Map.of("ph", p.passwordHash(), "dn", p.displayName(), "lg", p.language()));
        redis.expire(key(email), TTL);
    }

    /** Kaydi okur (silmez); yoksa null. */
    public Pending find(String email) {
        Map<Object, Object> m = redis.opsForHash().entries(key(email));
        if (m.isEmpty()) {
            return null;
        }
        return new Pending((String) m.get("ph"), (String) m.get("dn"), (String) m.get("lg"));
    }

    public void delete(String email) {
        redis.delete(key(email));
    }

    private static String key(String email) {
        return "reg:" + email;
    }
}
