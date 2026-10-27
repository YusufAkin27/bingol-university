package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.JwtProperties;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.Set;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

/**
 * Opak refresh token: Redis'te yalnizca SHA-256 ozeti saklanir (deger `uid:client`). Her kullanimda doner
 * (rotation); eski token tek kullanimliktir. Kullanici basina `rtu:<uid>` kumesi token ozetlerini indeksler;
 * boylece tum oturumlar (ya da yalniz bir istemci turunun oturumlari) tek hamlede kapatilabilir. Iptal edilen
 * token'in ozeti `rtx:<hash>` mezar tasi olarak tutulur: istemci "suresi doldu" ile "baska cihazdan giris yapildi"
 * ayrimini yapabilsin (token tahmin edilemez, sizinti yok).
 */
@Service
public class RefreshTokenService {

    public static final String WEB = "web";
    public static final String MOBILE = "mobile";

    private static final String TOKEN_PREFIX = "rt:";
    private static final String TOMBSTONE_PREFIX = "rtx:";

    /** Tuketilen refresh token'in sahibi ve istemci turu. */
    public record Session(Long userId, String client) {}

    private final StringRedisTemplate redis;
    private final Duration ttl;
    private final SecureRandom random = new SecureRandom();

    public RefreshTokenService(StringRedisTemplate redis, JwtProperties props) {
        this.redis = redis;
        this.ttl = Duration.ofDays(props.refreshTtlDays());
    }

    /** Bilinmeyen/bos deger "web" sayilir. */
    public static String normalizeClient(String client) {
        return client != null && MOBILE.equalsIgnoreCase(client.trim()) ? MOBILE : WEB;
    }

    public String issue(Long userId) {
        return issue(userId, WEB);
    }

    public String issue(Long userId, String client) {
        byte[] b = new byte[32];
        random.nextBytes(b);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
        String hash = Hashing.sha256(token);
        redis.opsForValue().set(TOKEN_PREFIX + hash, userId + ":" + normalizeClient(client), ttl);
        redis.opsForSet().add(userKey(userId), hash);
        redis.expire(userKey(userId), ttl);
        return token;
    }

    /** Token'i tuketir (tek kullanimlik); sahibini ve istemci turunu doner, gecersizse null. */
    public Session consumeSession(String token) {
        String hash = Hashing.sha256(token);
        String v = redis.opsForValue().getAndDelete(TOKEN_PREFIX + hash);
        if (v == null) {
            return null;
        }
        int i = v.indexOf(':');
        Long userId = Long.valueOf(i < 0 ? v : v.substring(0, i));
        redis.opsForSet().remove(userKey(userId), hash);
        return new Session(userId, i < 0 ? WEB : normalizeClient(v.substring(i + 1)));
    }

    /** Token'i tuketir ve sahibinin id'sini doner; gecersizse null. */
    public Long consume(String token) {
        Session s = consumeSession(token);
        return s == null ? null : s.userId();
    }

    /** Token daha once oturum iptaliyle (baska cihaz girisi, tum oturumlari kapatma) silindi mi? */
    public boolean wasRevoked(String token) {
        return Boolean.TRUE.equals(redis.hasKey(TOMBSTONE_PREFIX + Hashing.sha256(token)));
    }

    public void revoke(String token) {
        consume(token);
    }

    /** Kullanicinin tum refresh token'larini siler (sifre degisimi, "tum cihazlardan cik"); silinen sayisini doner. */
    public int revokeAll(Long userId) {
        Set<String> hashes = redis.opsForSet().members(userKey(userId));
        int n = 0;
        if (hashes != null && !hashes.isEmpty()) {
            redis.delete(hashes.stream().map(h -> TOKEN_PREFIX + h).toList());
            for (String h : hashes) {
                tombstone(h, userId);
            }
            n = hashes.size();
        }
        redis.delete(userKey(userId));
        return n;
    }

    /** Yalniz verilen istemci turundeki refresh token'lari siler; silinen sayisini doner. */
    public int revokeClient(Long userId, String client) {
        String want = normalizeClient(client);
        Set<String> hashes = redis.opsForSet().members(userKey(userId));
        int n = 0;
        if (hashes == null) {
            return 0;
        }
        for (String h : hashes) {
            String v = redis.opsForValue().get(TOKEN_PREFIX + h);
            if (v == null) {
                redis.opsForSet().remove(userKey(userId), h); // suresi dolmus
                continue;
            }
            int i = v.indexOf(':');
            String c = i < 0 ? WEB : normalizeClient(v.substring(i + 1));
            if (c.equals(want)) {
                redis.delete(TOKEN_PREFIX + h);
                redis.opsForSet().remove(userKey(userId), h);
                tombstone(h, userId);
                n++;
            }
        }
        return n;
    }

    private void tombstone(String hash, Long userId) {
        redis.opsForValue().set(TOMBSTONE_PREFIX + hash, String.valueOf(userId), ttl);
    }

    private static String userKey(Long userId) {
        return "rtu:" + userId;
    }
}
