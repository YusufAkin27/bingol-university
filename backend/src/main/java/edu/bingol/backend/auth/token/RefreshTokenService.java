package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.AuthProperties;
import edu.bingol.backend.config.JwtProperties;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.Optional;
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
    static final Duration MAX_REUSE_WINDOW = Duration.ofMinutes(60);
    /**
     * Kaybolan yanit icin yeniden deneme penceresi (FIX-P02/K1): eskiden 45 sn; mobilde arka plan/tunel donusleri bunu
     * asiyor ve calinti sanilip oturum kapaniyordu. Kayit AES-GCM ile ESKI token'a bagli oldugundan uzamasi guvenli.
     */
    static final Duration NEXT_TTL = Duration.ofMinutes(5);

    /** Tuketilen refresh token'in sahibi, istemci turu ve oturumun ilk giris ani (ms; 0 = eski token, bilinmiyor). */
    public record Session(Long userId, String client, long authTimeMs, String sid) {
        public Session(Long userId, String client, long authTimeMs) {
            this(userId, client, authTimeMs, null);
        }

        public Session(Long userId, String client) {
            this(userId, client, 0L, null);
        }
    }

    /**
     * Yeniden kullanilan (calinti suphesi) token'in ait oldugu OTURUM AILESI: ayni giriste (authTimeMs) rotasyonla
     * uretilmis zincir. authTimeMs &lt;= 0 ise aile bilinmiyor (eski kayit).
     */
    public record Reuse(long userId, String client, long authTimeMs, String sid) {
        public Reuse(long userId, String client, long authTimeMs) {
            this(userId, client, authTimeMs, null);
        }

        public boolean familyKnown() {
            return authTimeMs > 0;
        }
    }

    private record UsedMark(long owner, long usedAt, String client, long authTimeMs, String sid) {}

    private final StringRedisTemplate redis;
    private final Duration ttl;
    private final Duration sessionMax;
    private final Duration reuseWindow;
    private final Duration reuseGrace;
    private final SecureRandom random = new SecureRandom();

    public RefreshTokenService(StringRedisTemplate redis, JwtProperties props) {
        this(redis, props, new AuthProperties(Duration.ofHours(72), 90, Duration.ofMinutes(60), Duration.ofSeconds(10)));
    }

    @Autowired
    public RefreshTokenService(StringRedisTemplate redis, JwtProperties props, AuthProperties auth) {
        this.redis = redis;
        this.ttl = Duration.ofDays(props.refreshTtlDays());
        this.sessionMax = Duration.ofDays(Math.max(1, auth.sessionMaxDays()));
        // `rtused:` anahtari rotasyon basina bir kayit: 6 sa Redis bellegini (maxmemory 200mb) yiyordu (FIX-P02/A01#6);
        // calinti tespiti icin 60 dk yeter. Ayarin kendisi (AuthProperties, P10) daha buyukse burada kirpilir.
        this.reuseWindow = auth.refreshReuseWindow().compareTo(MAX_REUSE_WINDOW) > 0 ? MAX_REUSE_WINDOW
                : auth.refreshReuseWindow();
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
        return issue(userId, client, authTimeMs, null);
    }

    /**
     * `sid`: oturum kaydinin kimligi (cok oturum / "Cihazlarim"); rotasyonda korunur. null = kimliksiz (eski zincir):
     * deger eski bicimde (`uid:client:authTime`) yazilir.
     */
    public String issue(Long userId, String client, long authTimeMs, String sid) {
        long now = System.currentTimeMillis();
        long auth = authTimeMs > 0 ? authTimeMs : now;
        byte[] b = new byte[32];
        random.nextBytes(b);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
        String hash = Hashing.sha256(token);
        // Token omru mutlak oturum omrunu asamaz (kayan oturum sinirsiz uzamasin).
        long leftMs = auth + sessionMax.toMillis() - now;
        Duration life = leftMs >= ttl.toMillis() ? ttl : Duration.ofMillis(Math.max(leftMs, 1000));
        redis.opsForValue().set(TOKEN_PREFIX + hash,
                userId + ":" + normalizeClient(client) + ":" + auth + (sid == null || sid.isBlank() ? "" : ":" + sid), life);
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
        String[] p = v.split(":", 4);
        Long userId = Long.valueOf(p[0]);
        redis.opsForSet().remove(userKey(userId), hash);
        String client = p.length < 2 ? WEB : normalizeClient(p[1]);
        long authTime = p.length < 3 ? 0L : parseLong(p[2]);
        String sid = p.length < 4 || p[3].isBlank() ? null : p[3];
        if (markUsed) {
            // Deger: sahip:tuketimAni:istemci:girisAni[:sid] (aile kimligi = girisAni; yeniden kullanimda yalniz o aile kapanir)
            redis.opsForValue().set(USED_PREFIX + hash,
                    userId + ":" + System.currentTimeMillis() + ":" + client + ":" + authTime
                            + (sid == null ? "" : ":" + sid), reuseWindow);
        }
        return new Session(userId, client, authTime, sid);
    }

    /**
     * Zaten tuketilmis bir refresh token yeniden sunuldu mu (calinma/yeniden oynatma)? Sahibin id'sini doner; tuketim
     * toleransin icindeyse (kaybolan yanit/ag yeniden denemesi) veya isaret yoksa bos.
     */
    public OptionalLong detectReuse(String token) {
        return findReuse(token).map(r -> OptionalLong.of(r.userId())).orElse(OptionalLong.empty());
    }

    /**
     * {@link #detectReuse} ile ayni ama oturum ailesini de doner: cagiran YALNIZ o aileyi kapatir
     * ({@link #revokeFamily}); kullanicinin diger cihazlari etkilenmez (FIX-P02/K1).
     */
    public Optional<Reuse> findReuse(String token) {
        UsedMark m = usedMark(token);
        if (m == null || System.currentTimeMillis() - m.usedAt() < reuseGrace.toMillis()) {
            return Optional.empty();
        }
        return Optional.of(new Reuse(m.owner(), m.client(), m.authTimeMs(), m.sid()));
    }

    /**
     * Token az once tuketildi (tolerans penceresi icinde) ama rotasyon kaydi bulunamadi mi? Es zamanli ikinci istek:
     * ilk istek yeni cifti henuz yaziyor olabilir; cagiran kisa bekleyip yeniden dener ya da 409 ile "tekrar dene" der.
     */
    public boolean rotationInProgress(String token) {
        UsedMark m = usedMark(token);
        if (m == null || System.currentTimeMillis() - m.usedAt() >= reuseGrace.toMillis()) {
            return false;
        }
        // Rotasyon kaydi VARSA ama cift artik gecerli degilse (istemci yeni cifti alip yeniden dondurdu) is "suruyor"
        // degil, bitmis: cagiran 401 doner, istemci sonsuz 409 dongusune girmez.
        return !Boolean.TRUE.equals(redis.hasKey(NEXT_PREFIX + Hashing.sha256(token)));
    }

    private UsedMark usedMark(String token) {
        String v = redis.opsForValue().get(USED_PREFIX + Hashing.sha256(token));
        if (v == null) {
            return null;
        }
        String[] f = v.split(":", 5);
        long owner = parseLong(f[0]);
        if (f.length < 2 || owner <= 0) {
            return null;
        }
        return new UsedMark(owner, parseLong(f[1]), f.length < 3 ? WEB : normalizeClient(f[2]),
                f.length < 4 ? 0L : parseLong(f[3]), f.length < 5 || f[4].isBlank() ? null : f[4]);
    }

    /**
     * Tek bir OTURUM AILESINI (ayni giriste, authTimeMs'de, acilmis zincir) kapatir: ailenin canli refresh token'i
     * silinir ve mezar tasi birakilir. Kullanicinin diger cihazlari/girisleri etkilenmez. Access token'lar kendi
     * omruyle (en cok 15 dk) biter. Silinen token sayisini doner.
     */
    public int revokeFamily(Long userId, String client, long authTimeMs) {
        if (authTimeMs <= 0) {
            return 0;
        }
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
            String[] parts = v.split(":", 4);
            String c = parts.length < 2 ? WEB : normalizeClient(parts[1]);
            long auth = parts.length < 3 ? 0L : parseLong(parts[2]);
            if (auth == authTimeMs && c.equals(want)) {
                redis.delete(TOKEN_PREFIX + h);
                redis.opsForSet().remove(userKey(userId), h);
                tombstone(h, userId);
                n++;
            }
        }
        return n;
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

    /**
     * Cikis: token tuketilir ama "kullanildi" isareti birakilmaz (cikis yapilmis token calinma sayilmaz). Tuketilen
     * oturumu doner (gecersiz token icin null): cagiran oturum kaydini kapatir.
     */
    public Session revoke(String token) {
        return consume(token, false);
    }

    /**
     * Tek bir oturumu (sid) kapatir: o oturumun canli refresh token'i silinir ve mezar tasi birakilir; kullanicinin
     * diger cihazlari etkilenmez. Silinen token sayisini doner.
     */
    public int revokeSid(Long userId, String sid) {
        if (sid == null || sid.isBlank()) {
            return 0;
        }
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
            String[] parts = v.split(":", 4);
            if (parts.length >= 4 && sid.equals(parts[3])) {
                redis.delete(TOKEN_PREFIX + h);
                redis.opsForSet().remove(userKey(userId), h);
                tombstone(h, userId);
                n++;
            }
        }
        return n;
    }

    /** Kullanicinin tum refresh token'larini siler (sifre degisimi, "tum cihazlardan cik"); silinen sayisini doner. */
    public int revokeAll(Long userId) {
        // Dizin once ATOMIK olarak yan anahtara alinir (FIX-P02/A01#10): okuma ile silme arasinda issue()'nun SADD'ledigi
        // yeni token dizinden dusmez (yeni kume olusur, sonraki iptalde bulunur).
        String work = userKey(userId) + ":revoking";
        Set<String> hashes = null;
        if (Boolean.TRUE.equals(redis.hasKey(userKey(userId)))) {
            try {
                redis.rename(userKey(userId), work);
                hashes = redis.opsForSet().members(work);
            } catch (org.springframework.dao.DataAccessException e) {
                if (!isNoSuchKey(e)) {
                    throw e;
                }
                // hasKey ile rename arasinda baska iptal anahtari aldi: yapacak is kalmadi
            }
        }
        int n = 0;
        if (hashes != null && !hashes.isEmpty()) {
            redis.delete(hashes.stream().map(h -> TOKEN_PREFIX + h).toList());
            for (String h : hashes) {
                tombstone(h, userId);
            }
            n = hashes.size();
        }
        redis.delete(work);
        return n;
    }

    private static boolean isNoSuchKey(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            String m = t.getMessage();
            if (m != null && m.toLowerCase(java.util.Locale.ROOT).contains("no such key")) {
                return true;
            }
        }
        return false;
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
