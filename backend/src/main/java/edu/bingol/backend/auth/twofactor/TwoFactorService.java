package edu.bingol.backend.auth.twofactor;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.DeviceView;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.LoginChallengeResponse;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.StatusResponse;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * E-posta kodlu iki faktorlu dogrulama (docs/TWO_FACTOR_API.md). Giris: sifre dogrulandiktan sonra 2FA aciksa ve
 * cihaz guvenilir degilse token uretilmez, bir <b>challenge</b> acilir ({@code 2fa:<sha256(token)>} -> kullanici +
 * cihaz ozeti + istemci, 10 dk, tek kullanimlik) ve 6 haneli kod e-postaya gider. Kod, VerificationService'in
 * ("tf" alani) hash'li / 10 dk / 5 deneme / istemci kapsamli kalibini kullanir; challenge ayrica 5 yanlis denemede
 * silinir. Guvenilen cihaz = ClientContexts HMAC ozeti ({@code two_factor_device}); kullanici basina en cok 10.
 * Ham cihaz kimligi hicbir yerde saklanmaz/log'lanmaz.
 */
@Service
public class TwoFactorService {

    public static final Duration CHALLENGE_TTL = Duration.ofMinutes(10);
    public static final int MAX_DEVICES = 10;
    /** Bir challenge icin toplam yanlis deneme; asilirsa challenge ve kod silinir. */
    static final int MAX_CHALLENGE_ATTEMPTS = 5;
    /** Kullanici basina saatlik kod postasi tavani (giris + etkinlestirme + yeniden gonderme birlikte). */
    static final int MAX_CODE_MAILS_PER_HOUR = 10;

    static final String CHALLENGE_PREFIX = "2fa:";
    static final String ATTEMPT_PREFIX = "2fa:att:";

    private final UserRepository users;
    private final TwoFactorDeviceRepository devices;
    private final VerificationService verification;
    private final StringRedisTemplate redis;
    private final PasswordEncoder encoder;
    private final RateLimiter limiter;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public TwoFactorService(UserRepository users, TwoFactorDeviceRepository devices, VerificationService verification,
                            StringRedisTemplate redis, PasswordEncoder encoder, RateLimiter limiter, Clock clock) {
        this.users = users;
        this.devices = devices;
        this.verification = verification;
        this.redis = redis;
        this.encoder = encoder;
        this.limiter = limiter;
        this.clock = clock;
    }

    /** Acik challenge'in cozulmus hali (cihaz ozeti giris aninda; token'dan yeniden uretilemez). */
    public record Challenge(Long userId, String deviceHash, String client, String platform, String appVersion) {}

    // ------------------------------------------------------------------ giris akisi

    /** Cihaz guvenilir mi? Evetse son kullanim zamani guncellenir (kod istenmez). Cihaz ozeti yoksa hayir. */
    @Transactional
    public boolean touchIfTrusted(Long userId, String deviceHash) {
        if (deviceHash == null) {
            return false;
        }
        return devices.findByUserIdAndDeviceHash(userId, deviceHash).map(d -> {
            d.setLastUsedAt(clock.instant());
            devices.save(d);
            return true;
        }).orElse(false);
    }

    /**
     * Challenge acar ve kodu e-postaya kuyruklar. Sifre ZATEN dogrulanmistir (bu yuzden varlik sizmaz). Kod
     * gonderilemezse challenge silinir ve hata yukari gider (503 MAIL_UNAVAILABLE).
     */
    public LoginChallengeResponse begin(User user, ClientContext ctx, String client) {
        limiter.check("tf:code:user:" + user.getId(), MAX_CODE_MAILS_PER_HOUR, Duration.ofHours(1));
        String token = newToken();
        String key = CHALLENGE_PREFIX + Hashing.sha256(token);
        redis.opsForValue().set(key, encode(user.getId(), ctx, client), CHALLENGE_TTL);
        try {
            verification.issueTwoFactor(String.valueOf(user.getId()), user.getEmail(), Lang.of(user.getLanguage()));
        } catch (RuntimeException e) {
            redis.delete(key);
            throw e;
        }
        return new LoginChallengeResponse(true, token, maskEmail(user.getEmail()), CHALLENGE_TTL.toSeconds());
    }

    /** Challenge'i tuketmeden okur; yok/suresi dolmussa 400 TWO_FACTOR_CHALLENGE_EXPIRED. */
    public Challenge peek(String challengeToken) {
        String raw = challengeToken == null ? null : redis.opsForValue().get(CHALLENGE_PREFIX + Hashing.sha256(challengeToken));
        Challenge c = raw == null ? null : decode(raw);
        if (c == null) {
            throw challengeExpired();
        }
        return c;
    }

    /**
     * Kodu dogrular. Dogruysa challenge tuketilir (tek kullanimlik; es zamanli iki istekten yalniz biri gecer).
     * Yanlissa 400 TWO_FACTOR_CODE_INVALID; challenge icin 5. yanlista challenge ve kod silinir (sonrasi EXPIRED).
     * Kod kilidi/limit asilirsa 429 TOO_MANY_ATTEMPTS.
     */
    public void verifyAndConsume(String challengeToken, Challenge ch, String code, ClientContext ctx) {
        String hash = Hashing.sha256(challengeToken);
        String key = CHALLENGE_PREFIX + hash;
        String attKey = ATTEMPT_PREFIX + hash;
        String subject = String.valueOf(ch.userId());
        boolean ok = verification.verifyTwoFactor(subject, code == null ? "" : code.trim(), scopeOf(ctx));
        if (!ok) {
            Long n = redis.opsForValue().increment(attKey);
            if (n != null && n == 1) {
                redis.expire(attKey, CHALLENGE_TTL);
            }
            if (n != null && n >= MAX_CHALLENGE_ATTEMPTS) {
                redis.delete(List.of(key, attKey));
                verification.clearTwoFactor(subject);
            }
            throw new ApiException(HttpStatus.BAD_REQUEST, "TWO_FACTOR_CODE_INVALID",
                    "Doğrulama kodu geçersiz veya süresi dolmuş.");
        }
        if (!Boolean.TRUE.equals(redis.delete(key))) {
            throw challengeExpired();
        }
        redis.delete(attKey);
    }

    /** Ayni challenge icin yeni kod (sinir cagiranda: 3 / 10 dk). Challenge omru uzar. */
    public long resend(String challengeToken, Challenge ch) {
        User u = users.findById(ch.userId()).orElseThrow(TwoFactorService::challengeExpired);
        limiter.check("tf:code:user:" + u.getId(), MAX_CODE_MAILS_PER_HOUR, Duration.ofHours(1));
        verification.issueTwoFactor(String.valueOf(u.getId()), u.getEmail(), Lang.of(u.getLanguage()));
        redis.expire(CHALLENGE_PREFIX + Hashing.sha256(challengeToken), CHALLENGE_TTL);
        return CHALLENGE_TTL.toSeconds();
    }

    // ------------------------------------------------------------------ guvenilen cihazlar

    /** Cihazi guvenilir yapar (varsa gunceller); kullanici basina en cok 10, fazlasinda en eski(ler) duser. */
    @Transactional
    public void trust(Long userId, String deviceHash, String platform, String appVersion) {
        if (deviceHash == null) {
            return;
        }
        Instant now = clock.instant();
        TwoFactorDevice d = devices.findByUserIdAndDeviceHash(userId, deviceHash).orElse(null);
        if (d == null) {
            d = new TwoFactorDevice();
            d.setUserId(userId);
            d.setDeviceHash(deviceHash);
            d.setCreatedAt(now);
        }
        d.setLabel(label(platform, appVersion));
        d.setLastUsedAt(now);
        devices.save(d);
        List<TwoFactorDevice> all = devices.findByUserIdOrderByLastUsedAtDesc(userId);
        for (int i = MAX_DEVICES; i < all.size(); i++) {
            devices.delete(all.get(i));
        }
    }

    /** Tum guvenilen cihazlari siler (sifre sifirlama/degisimi, logout-all, 2FA kapatma). */
    @Transactional
    public int clearDevices(Long userId) {
        return devices.deleteAllForUser(userId);
    }

    // ------------------------------------------------------------------ ayarlar (oturum acik kullanici)

    @Transactional(readOnly = true)
    public StatusResponse status(Long userId, String currentDeviceHash) {
        User u = activeUser(userId);
        long count = devices.countByUserId(userId);
        boolean current = currentDeviceHash != null
                && devices.findByUserIdAndDeviceHash(userId, currentDeviceHash).isPresent();
        return new StatusResponse(u.isTwoFactorEnabled(), count, current);
    }

    /** Etkinlestirme kodunu e-postaya yollar; zaten aciksa 409 TWO_FACTOR_ALREADY_ENABLED. */
    public void requestEnable(Long userId) {
        User u = activeUser(userId);
        if (u.isTwoFactorEnabled()) {
            throw new ApiException(HttpStatus.CONFLICT, "TWO_FACTOR_ALREADY_ENABLED",
                    "İki faktörlü doğrulama zaten açık.");
        }
        limiter.check("tf:code:user:" + userId, MAX_CODE_MAILS_PER_HOUR, Duration.ofHours(1));
        verification.issueTwoFactor(String.valueOf(userId), u.getEmail(), Lang.of(u.getLanguage()));
    }

    /** Kodu dogrular, 2FA'yi acar ve bu cihazi guvenilir yapar. */
    @Transactional
    public void confirmEnable(Long userId, String code, ClientContext ctx) {
        User u = activeUser(userId);
        if (u.isTwoFactorEnabled()) {
            throw new ApiException(HttpStatus.CONFLICT, "TWO_FACTOR_ALREADY_ENABLED",
                    "İki faktörlü doğrulama zaten açık.");
        }
        if (!verification.verifyTwoFactor(String.valueOf(userId), code == null ? "" : code.trim(), scopeOf(ctx))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TWO_FACTOR_CODE_INVALID",
                    "Doğrulama kodu geçersiz veya süresi dolmuş.");
        }
        u.setTwoFactorEnabled(true);
        u.setTwoFactorEnabledAt(clock.instant());
        users.save(u);
        if (ctx != null) {
            trust(userId, ctx.deviceHash(), ctx.platform(), ctx.appVersion());
        }
    }

    /** Sifre ister; kapatinca tum guvenilen cihazlar silinir. Kapaliysa 409 TWO_FACTOR_NOT_ENABLED. */
    @Transactional
    public void disable(Long userId, String password) {
        User u = activeUser(userId);
        if (!u.isTwoFactorEnabled()) {
            throw notEnabled();
        }
        if (password == null || password.getBytes(StandardCharsets.UTF_8).length > 72
                || !encoder.matches(password, u.getPasswordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PASSWORD", "Şifre hatalı.");
        }
        reset(u);
    }

    /**
     * Yonetici kurtarma kapatmasi (sifre istemez; gerekce/denetim cagiranda). Zaten kapaliysa 409
     * TWO_FACTOR_NOT_ENABLED.
     */
    @Transactional
    public void forceDisable(Long userId) {
        User u = users.findById(userId).filter(x -> x.getStatus() != UserStatus.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        if (!u.isTwoFactorEnabled()) {
            throw notEnabled();
        }
        reset(u);
    }

    private void reset(User u) {
        u.setTwoFactorEnabled(false);
        u.setTwoFactorEnabledAt(null);
        users.save(u);
        devices.deleteAllForUser(u.getId());
        verification.clearTwoFactor(String.valueOf(u.getId()));
    }

    @Transactional(readOnly = true)
    public List<DeviceView> listDevices(Long userId, String currentDeviceHash) {
        return devices.findByUserIdOrderByLastUsedAtDesc(userId).stream()
                .map(d -> new DeviceView(d.getId(), d.getLabel(), d.getCreatedAt().toString(),
                        d.getLastUsedAt().toString(), currentDeviceHash != null && currentDeviceHash.equals(d.getDeviceHash())))
                .toList();
    }

    /** Idempotent: kayit yoksa (ya da baskasinin ise) sessizce gecer. Mevcut oturumu kapatmaz. */
    @Transactional
    public void removeDevice(Long userId, Long deviceId) {
        devices.findByIdAndUserId(deviceId, userId).ifPresent(devices::delete);
    }

    // ------------------------------------------------------------------ yardimcilar

    private User activeUser(Long userId) {
        return users.findById(userId).filter(User::isActive)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Oturum geçersiz."));
    }

    private static ApiException notEnabled() {
        return new ApiException(HttpStatus.CONFLICT, "TWO_FACTOR_NOT_ENABLED", "İki faktörlü doğrulama açık değil.");
    }

    public static ApiException challengeExpired() {
        return new ApiException(HttpStatus.BAD_REQUEST, "TWO_FACTOR_CHALLENGE_EXPIRED",
                "Doğrulama oturumunun süresi doldu; tekrar giriş yapın.");
    }

    /** Yanlis deneme sayaci (kullanici, ag) cifti basinadir: baskasi gercek kullanicinin butcesini tuketemez. */
    private static String scopeOf(ClientContext ctx) {
        return ctx == null || ctx.ip() == null ? null : ClientIp.limitKey(ctx.ip());
    }

    private String newToken() {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
    }

    /** "ay***@bingol.edu.tr": yerel kismin ilk 2 harfi + adres alani (tam adres sizdirilmaz). */
    static String maskEmail(String email) {
        int at = email == null ? -1 : email.indexOf('@');
        if (at < 1) {
            return "***";
        }
        return email.substring(0, Math.min(2, at)) + "***" + email.substring(at);
    }

    static String label(String platform, String appVersion) {
        boolean known = platform != null && !platform.isBlank() && !"UNKNOWN".equals(platform);
        if (!known && appVersion == null) {
            return null;
        }
        return ((known ? platform : "") + (appVersion != null ? (known ? " " : "") + appVersion : "")).trim();
    }

    /** uid|cihazOzeti|istemci|platform|surum (bos alan = bos metin). Alanlar '|' icermez (desen/sabit kume). */
    private static String encode(Long userId, ClientContext ctx, String client) {
        return userId + "|" + nz(ctx == null ? null : ctx.deviceHash()) + "|" + nz(client) + "|"
                + nz(ctx == null ? null : ctx.platform()) + "|" + nz(ctx == null ? null : ctx.appVersion());
    }

    private static Challenge decode(String raw) {
        String[] f = raw.split("\\|", -1);
        if (f.length != 5) {
            return null;
        }
        try {
            return new Challenge(Long.parseLong(f[0]), blank(f[1]), blank(f[2]), blank(f[3]), blank(f[4]));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private static String blank(String s) {
        return s.isEmpty() ? null : s;
    }
}
