package edu.bingol.backend.auth.token;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Dogrulanmamis kayit verisi (sifre ozeti, ad, dil) e-posta dogrulanana kadar Redis'te tutulur; veritabaninda
 * hesap satiri olusmaz. Boylece baskasinin e-postasiyla onceden kayit acip sifreyi "on ele gecirme" mumkun olmaz.
 */
@Component
public class PendingRegistrationStore {

    public record Pending(String passwordHash, String displayName, String language, String faculty,
                          String department, String grade) {
        public Pending(String passwordHash, String displayName, String language) {
            this(passwordHash, displayName, language, null, null, null);
        }
    }

    private static final Duration TTL = Duration.ofHours(1);

    private final StringRedisTemplate redis;

    public PendingRegistrationStore(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void save(String email, Pending p) {
        Map<String, String> m = new HashMap<>(Map.of("ph", p.passwordHash(), "dn", p.displayName(), "lg", p.language()));
        if (p.faculty() != null) {
            m.put("fa", p.faculty());
        }
        if (p.department() != null) {
            m.put("de", p.department());
        }
        if (p.grade() != null) {
            m.put("gr", p.grade());
        }
        redis.opsForHash().putAll(key(email), m);
        redis.expire(key(email), TTL);
    }

    /** Kaydi okur (silmez); yoksa null. */
    public Pending find(String email) {
        Map<Object, Object> m = redis.opsForHash().entries(key(email));
        if (m.isEmpty()) {
            return null;
        }
        return new Pending((String) m.get("ph"), (String) m.get("dn"), (String) m.get("lg"),
                (String) m.get("fa"), (String) m.get("de"), (String) m.get("gr"));
    }

    public void delete(String email) {
        redis.delete(key(email));
    }

    private static String key(String email) {
        return "reg:" + email;
    }
}
