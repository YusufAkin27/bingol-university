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
    /** Rotasyon kaydi (T-007): eski token ozeti -> SIFRELI yeni cift; kaybolan yanit yeniden denemesi ayni cifti alir. */
    private static final String NEXT_PREFIX = "rtnext:";
    static final Duration NEXT_TTL = Duration.ofSeconds(45);

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

    /**
     * Rotasyon sonucunu (yeni token cifti, metin) kaydeder: AES-GCM, anahtar = SHA-256(ESKI token). Redis'te yalniz
     * eski token'in OZETI durur, anahtar ham token'dan turer; Redis sizintisi tek basina yeni refresh token'i vermez.
     * Kayit {@link #NEXT_TTL} kadar yasar. Hata yutulur (idempotans en-iyi-caba; rotasyonu bozmaz).
     */
    public void rememberRotation(String oldToken, String payload) {
        try {
            redis.opsForValue().set(NEXT_PREFIX + Hashing.sha256(oldToken), seal(oldToken, payload), NEXT_TTL);
        } catch (RuntimeException e) {
            // yoksay
        }
    }

    /**
     * Daha once tuketilmis `oldToken` icin kayitli rotasyon sonucunu doner (yoksa/cozulemezse null). Yeni refresh
     * token hala gecerli degilse (yeniden dondu, iptal edildi) null: eski cift canlandirilmaz.
     */
    public String replayRotation(String oldToken, java.util.function.Predicate<String> stillValid) {
        String sealed = redis.opsForValue().get(NEXT_PREFIX + Hashing.sha256(oldToken));
        if (sealed == null) {
            return null;
        }
        String payload = open(oldToken, sealed);
        return payload != null && stillValid.test(payload) ? payload : null;
    }

    private static byte[] key(String token) {
        try {
            return java.security.MessageDigest.getInstance("SHA-256").digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private String seal(String token, String payload) {
        try {
            byte[] iv = new byte[12];
            random.nextBytes(iv);
            javax.crypto.Cipher c = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding");
            c.init(javax.crypto.Cipher.ENCRYPT_MODE, new javax.crypto.spec.SecretKeySpec(key(token), "AES"),
                    new javax.crypto.spec.GCMParameterSpec(128, iv));
            byte[] ct = c.doFinal(payload.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            byte[] all = new byte[iv.length + ct.length];
            System.arraycopy(iv, 0, all, 0, iv.length);
            System.arraycopy(ct, 0, all, iv.length, ct.length);
            return Base64.getEncoder().encodeToString(all);
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String open(String token, String sealed) {
        try {
            byte[] all = Base64.getDecoder().decode(sealed);
            if (all.length < 13) {
                return null;
            }
            javax.crypto.Cipher c = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding");
            c.init(javax.crypto.Cipher.DECRYPT_MODE, new javax.crypto.spec.SecretKeySpec(key(token), "AES"),
                    new javax.crypto.spec.GCMParameterSpec(128, all, 0, 12));
            return new String(c.doFinal(all, 12, all.length - 12), java.nio.charset.StandardCharsets.UTF_8);
        } catch (java.security.GeneralSecurityException | IllegalArgumentException e) {
            return null;
        }
    }

    private static long parseLong(String s) {
        try {
            return Long.parseLong(s);
        } catch (NumberFormatException e) {
            return 0L;
        }
    }

    /**
     * Token'i TUKETMEDEN sahibinin id'sini doner (hiz siniri anahtari icin); gecersiz/tuketilmis/bilinmeyen token icin
     * null. Salt okuma: tek Redis GET.
     */
    public Long peekUserId(String token) {
        if (token == null || token.isBlank() || token.length() > 256) {
            return null;
        }
        String v = redis.opsForValue().get(TOKEN_PREFIX + Hashing.sha256(token));
        if (v == null) {
            return null;
        }
        int i = v.indexOf(':');
        long id = parseLong(i < 0 ? v : v.substring(0, i));
        return id > 0 ? id : null;
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

    /** Iptal mezar tasindaki sahip (T-009): iptalin nedenini ayirt etmek icin; kayit yoksa null. */
    public Long revokedOwner(String token) {
        String v = redis.opsForValue().get(TOMBSTONE_PREFIX + Hashing.sha256(token));
        long id = v == null ? 0 : parseLong(v);
        return id > 0 ? id : null;
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
            // Deger "uid:client:authTimeMs" (eski kayitlar "uid:client" ya da "uid"): istemci ikinci parcadir.
            String[] parts = v.split(":", 3);
            String c = parts.length < 2 ? WEB : normalizeClient(parts[1]);
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
