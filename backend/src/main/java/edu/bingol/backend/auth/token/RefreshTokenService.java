package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.AuthProperties;
import edu.bingol.backend.config.JwtProperties;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.OptionalLong;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

/**
 * Opak refresh token: Redis'te yalnizca SHA-256 ozeti saklanir (deger `uid:client:authTimeMs`; authTime girisin
 * anidir ve rotasyonlarda korunur: mutlak oturum omru `app.auth.session-max-days`). Her kullanimda doner
 * (rotation); eski token tek kullanimliktir. Tuketilen token `rtused:<hash>` isaretiyle anilir: ayni token
 * toleransin ({@code refreshReuseGrace}) otesinde tekrar sunulursa CALINMA sayilir (bkz. {@link #detectReuse}). Kullanici basina `rtu:<uid>` kumesi token ozetlerini indeksler;
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
    private static final String USED_PREFIX = "rtused:";

    /** Tuketilen refresh token'in sahibi, istemci turu ve oturumun ilk giris ani (ms; 0 = eski token, bilinmiyor). */
    public record Session(Long userId, String client, long authTimeMs) {
        public Session(Long userId, String client) {
            this(userId, client, 0L);
        }
    }

    private final StringRedisTemplate redis;
    private final Duration ttl;
    private final Duration sessionMax;
    private final Duration reuseWindow;
    private final Duration reuseGrace;
    private final SecureRandom random = new SecureRandom();

    public RefreshTokenService(StringRedisTemplate redis, JwtProperties props) {
        this(redis, props, new AuthProperties(Duration.ofHours(72), 90, Duration.ofHours(6), Duration.ofSeconds(10)));
    }

    @Autowired
    public RefreshTokenService(StringRedisTemplate redis, JwtProperties props, AuthProperties auth) {
        this.redis = redis;
        this.ttl = Duration.ofDays(props.refreshTtlDays());
        this.sessionMax = Duration.ofDays(Math.max(1, auth.sessionMaxDays()));
        this.reuseWindow = auth.refreshReuseWindow();
        this.reuseGrace = auth.refreshReuseGrace();
    }

    /** Bilinmeyen/bos deger "web" sayilir. */
    public static String normalizeClient(String client) {
        return client != null && MOBILE.equalsIgnoreCase(client.trim()) ? MOBILE : WEB;
    }

    public String issue(Long userId) {
        return issue(userId, WEB);
    }

    public String issue(Long userId, String client) {
        return issue(userId, client, 0L);
    }

    /** `authTimeMs` &lt;= 0 ise simdi (yeni giris); rotasyonda onceki oturumun degeri korunur. */
    public String issue(Long userId, String client, long authTimeMs) {
        long now = System.currentTimeMillis();
        long auth = authTimeMs > 0 ? authTimeMs : now;
        byte[] b = new byte[32];
        random.nextBytes(b);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
        String hash = Hashing.sha256(token);
        // Token omru mutlak oturum omrunu asamaz (kayan oturum sinirsiz uzamasin).
        long leftMs = auth + sessionMax.toMillis() - now;
        Duration life = leftMs >= ttl.toMillis() ? ttl : Duration.ofMillis(Math.max(leftMs, 1000));
        redis.opsForValue().set(TOKEN_PREFIX + hash, userId + ":" + normalizeClient(client) + ":" + auth, life);
        redis.opsForSet().add(userKey(userId), hash);
        redis.expire(userKey(userId), ttl);
        return token;
    }

    /** Mutlak oturum omru (girisin anindan) doldu mu? Eski token'larda (authTime yok) false. */
    public boolean isExpired(Session s) {
        return s != null && s.authTimeMs() > 0
                && System.currentTimeMillis() - s.authTimeMs() > sessionMax.toMillis();
    }

    /** Token'i tuketir (tek kullanimlik); sahibini ve istemci turunu doner, gecersizse null. */
    public Session consumeSession(String token) {
        return consume(token, true);
    }

    private Session consume(String token, boolean markUsed) {
        String hash = Hashing.sha256(token);
        String v = redis.opsForValue().getAndDelete(TOKEN_PREFIX + hash);
        if (v == null) {
            return null;
        }
        String[] p = v.split(":", 3);
        Long userId = Long.valueOf(p[0]);
        redis.opsForSet().remove(userKey(userId), hash);
        if (markUsed) {
            redis.opsForValue().set(USED_PREFIX + hash, userId + ":" + System.currentTimeMillis(), reuseWindow);
        }
        return new Session(userId, p.length < 2 ? WEB : normalizeClient(p[1]), p.length < 3 ? 0L : parseLong(p[2]));
    }

    /**
     * Zaten tuketilmis bir refresh token yeniden sunuldu mu (calinma/yeniden oynatma)? Sahibin id'sini doner; tuketim
     * toleransin icindeyse (kaybolan yanit/ag yeniden denemesi) veya isaret yoksa bos. Cagiran tum oturumlari
     * kapatmalidir (bir kopyayi saldirgan kullanmis olabilir).
     */
    public OptionalLong detectReuse(String token) {
        String v = redis.opsForValue().get(USED_PREFIX + Hashing.sha256(token));
        if (v == null) {
            return OptionalLong.empty();
        }
        int i = v.indexOf(':');
        if (i < 0) {
            return OptionalLong.empty();
        }
        long usedAt = parseLong(v.substring(i + 1));
        long owner = parseLong(v.substring(0, i));
        if (owner <= 0 || System.currentTimeMillis() - usedAt < reuseGrace.toMillis()) {
            return OptionalLong.empty();
        }
        return OptionalLong.of(owner);
    }

    private static long parseLong(String s) {
        try {
            return Long.parseLong(s);
        } catch (NumberFormatException e) {
            return 0L;
        }
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

    /** Cikis: token tuketilir ama "kullanildi" isareti birakilmaz (cikis yapilmis token calinma sayilmaz). */
    public void revoke(String token) {
        consume(token, false);
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
