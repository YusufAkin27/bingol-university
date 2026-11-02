package edu.bingol.backend.auth.twofactor;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.SessionsRevokedEvent;
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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.EventListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * E-posta kodlu iki faktorlu dogrulama (docs/TWO_FACTOR_API.md). Giris: sifre dogrulandiktan sonra 2FA aciksa ve
 * cihaz guvenilir degilse token uretilmez, bir <b>challenge</b> acilir ({@code 2fa:<sha256(token)>} -> kullanici +
 * cihaz ozeti + istemci + sifre degisim isareti, 10 dk, tek kullanimlik) ve 6 haneli kod e-postaya gider. Kod
 * CHALLENGE'a baglidir (VerificationService "tf" alani, konu = {@code <kullanici>:<challenge ozeti>}): baska bir
 * challenge'in kodu bu challenge'i gecmez; hash'li / 10 dk / 5 deneme / istemci kapsamli kalip aynen gecerlidir.
 * Challenge ayrica 5 yanlis denemede silinir; ust uste 3 tukenen challenge yeni cihazdan girisi 24 saat kilitler.
 * Sifre degisimi/sifirlama, "tum cihazlardan cik" ya da 2FA kapatma challenge'i gecersiz kilar.
 * Guvenilen cihaz = ClientContexts HMAC ozeti ({@code two_factor_device}); kullanici basina en cok 10, bosta
 * {@code app.twofactor.device-ttl-days} (60) gun. Ham cihaz kimligi hicbir yerde saklanmaz/log'lanmaz.
 */
@Service
public class TwoFactorService {

    private static final Logger log = LoggerFactory.getLogger(TwoFactorService.class);

    public static final Duration CHALLENGE_TTL = Duration.ofMinutes(10);
    public static final int MAX_DEVICES = 10;
    /** Bir challenge icin toplam yanlis deneme; asilirsa challenge ve kod silinir. */
    static final int MAX_CHALLENGE_ATTEMPTS = 5;
    /** Kullanici basina saatlik kod postasi tavani (giris + etkinlestirme + yeniden gonderme birlikte). */
    static final int MAX_CODE_MAILS_PER_HOUR = 10;
    /** 24 saat icinde bu kadar challenge tukenirse (5 yanlis kod) yeni cihazdan giris kilitlenir. */
    static final int MAX_EXHAUSTED_CHALLENGES = 3;
    static final Duration LOCK_TTL = Duration.ofHours(24);

    static final String CHALLENGE_PREFIX = "2fa:";
    static final String ATTEMPT_PREFIX = "2fa:att:";
    static final String EXHAUSTED_PREFIX = "2fa:exh:";
    static final String LOCK_PREFIX = "2fa:lock:";
    static final String NOTIFIED_PREFIX = "2fa:notif:";

    private final UserRepository users;
    private final TwoFactorDeviceRepository devices;
    private final VerificationService verification;
    private final StringRedisTemplate redis;
    private final PasswordEncoder encoder;
    private final RateLimiter limiter;
    private final Clock clock;
    private final SessionService sessions;
    private final TwoFactorNotifier notifier;
    private final SecureRandom random = new SecureRandom();
    /** Guvenilen cihazin bosta kalma siniri (gun); 0 veya eksi = sinirsiz. */
    @Value("${app.twofactor.device-ttl-days:60}")
    private int deviceTtlDays = 60;

    public TwoFactorService(UserRepository users, TwoFactorDeviceRepository devices, VerificationService verification,
                            StringRedisTemplate redis, PasswordEncoder encoder, RateLimiter limiter, Clock clock,
                            SessionService sessions, TwoFactorNotifier notifier) {
        this.users = users;
        this.devices = devices;
        this.verification = verification;
        this.redis = redis;
        this.encoder = encoder;
        this.limiter = limiter;
        this.clock = clock;
        this.sessions = sessions;
        this.notifier = notifier;
    }

    void setDeviceTtlDays(int days) {
        this.deviceTtlDays = days;
    }

    /** Acik challenge'in cozulmus hali (cihaz ozeti giris aninda; token'dan yeniden uretilemez). */
    public record Challenge(Long userId, String deviceHash, String client, String platform, String appVersion) {}

    // ------------------------------------------------------------------ giris akisi

    /**
     * Cihaz guvenilir mi? Evetse son kullanim zamani guncellenir (kod istenmez). Cihaz ozeti yoksa hayir. Bosta kalma
     * siniri asilmis kayit guvenilmez sayilir ve silinir (kaybolan/satilan telefon sonsuza dek kodsuz girmesin).
     */
    @Transactional
    public boolean touchIfTrusted(Long userId, String deviceHash) {
        if (deviceHash == null) {
            return false;
        }
        Instant now = clock.instant();
        return devices.findByUserIdAndDeviceHash(userId, deviceHash).map(d -> {
            if (idleExpired(d, now)) {
                devices.delete(d);
                return false;
            }
            d.setLastUsedAt(now);
            devices.save(d);
            return true;
        }).orElse(false);
    }

    private boolean idleExpired(TwoFactorDevice d, Instant now) {
        return deviceTtlDays > 0 && d.getLastUsedAt() != null
                && d.getLastUsedAt().isBefore(now.minus(Duration.ofDays(deviceTtlDays)));
    }

    /**
     * Challenge acar ve kodu e-postaya kuyruklar. Sifre ZATEN dogrulanmistir (bu yuzden varlik sizmaz). Kod
     * gonderilemezse challenge silinir ve hata yukari gider (503 MAIL_UNAVAILABLE). Gunluk posta kotasi doluysa
     * hicbir sey acilmaz (503 MAIL_QUOTA_EXHAUSTED): kod hic gitmeyecekse kullanici 202 ile kilitli kalmasin.
     * Yeni cihaz kilidi aciksa 429 TWO_FACTOR_LOCKED.
     */
    public LoginChallengeResponse begin(User user, ClientContext ctx, String client) {
        if (Boolean.TRUE.equals(redis.hasKey(LOCK_PREFIX + user.getId()))) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "TWO_FACTOR_LOCKED",
                    "Çok sayıda hatalı doğrulama kodu girildi; yeni cihazdan giriş 24 saat kilitlendi.");
        }
        verification.requireAccountMailQuota();
        limiter.check("tf:code:user:" + user.getId(), MAX_CODE_MAILS_PER_HOUR, Duration.ofHours(1));
        String token = newToken();
        String hash = Hashing.sha256(token);
        String key = CHALLENGE_PREFIX + hash;
        redis.opsForValue().set(key, encode(user.getId(), ctx, client, currentMarker(user.getId())), CHALLENGE_TTL);
        try {
            verification.issueTwoFactor(challengeSubject(user.getId(), hash), user.getEmail(), Lang.of(user.getLanguage()));
        } catch (RuntimeException e) {
            redis.delete(key);
            throw e;
        }
        return new LoginChallengeResponse(true, token, maskEmail(user.getEmail()), CHALLENGE_TTL.toSeconds(),
                verification.resendCooldownSeconds());
    }

    /**
     * Challenge'i tuketmeden okur; yok/suresi dolmussa ya da sifre/oturum iptali (sifre degisimi/sifirlama, tum
     * cihazlardan cik) challenge'dan SONRA olduysa 400 TWO_FACTOR_CHALLENGE_EXPIRED.
     */
    public Challenge peek(String challengeToken) {
        String raw = challengeToken == null ? null : redis.opsForValue().get(CHALLENGE_PREFIX + Hashing.sha256(challengeToken));
        String[] f = raw == null ? null : raw.split("\\|", -1);
        Challenge c = f == null ? null : decode(f);
        if (c == null || !markerOf(f).equals(currentMarker(c.userId()))) {
            throw challengeExpired();
        }
        return c;
    }

    /**
     * Kodu dogrular. Dogruysa challenge tuketilir (tek kullanimlik; es zamanli iki istekten yalniz biri gecer).
     * Yanlissa 400 TWO_FACTOR_CODE_INVALID; challenge icin 5. yanlista challenge ve kod silinir (sonrasi EXPIRED) ve
     * tukenen challenge sayaci artar. Kod kilidi/limit asilirsa 429 TOO_MANY_ATTEMPTS.
     */
    public void verifyAndConsume(String challengeToken, Challenge ch, String code, ClientContext ctx) {
        peek(challengeToken); // peek ile bu cagri arasinda iptal olduysa kabul etme
        String hash = Hashing.sha256(challengeToken);
        String key = CHALLENGE_PREFIX + hash;
        String attKey = ATTEMPT_PREFIX + hash;
        String subject = challengeSubject(ch.userId(), hash);
        boolean ok = verification.verifyTwoFactor(subject, code == null ? "" : code.trim(), scopeOf(ctx));
        if (!ok) {
            Long n = redis.opsForValue().increment(attKey);
            if (n != null && n == 1) {
                redis.expire(attKey, CHALLENGE_TTL);
            }
            if (n != null && n >= MAX_CHALLENGE_ATTEMPTS) {
                redis.delete(List.of(key, attKey));
                verification.clearTwoFactor(subject);
                onChallengeExhausted(ch.userId());
            }
            throw new ApiException(HttpStatus.BAD_REQUEST, "TWO_FACTOR_CODE_INVALID",
                    "Doğrulama kodu geçersiz veya süresi dolmuş.");
        }
        if (!Boolean.TRUE.equals(redis.delete(key))) {
            throw challengeExpired();
        }
        redis.delete(attKey);
        redis.delete(EXHAUSTED_PREFIX + ch.userId());
    }

    /**
     * Tukenen challenge sayaci (24 sa): MAX_EXHAUSTED_CHALLENGES'e ulasinca yeni cihazdan giris 24 saat kilitlenir ve
     * kullaniciya (gunde en cok 1) bildirim + e-posta gider. Hata cagirana sizmaz.
     */
    private void onChallengeExhausted(Long userId) {
        try {
            String exh = EXHAUSTED_PREFIX + userId;
            Long n = redis.opsForValue().increment(exh);
            if (n != null && n == 1) {
                redis.expire(exh, LOCK_TTL);
            }
            if (n != null && n >= MAX_EXHAUSTED_CHALLENGES) {
                redis.opsForValue().set(LOCK_PREFIX + userId, "1", LOCK_TTL);
                if (Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(NOTIFIED_PREFIX + userId, "1", LOCK_TTL))) {
                    users.findById(userId).ifPresent(u -> notifier.notify(u, TwoFactorNotifier.Event.WRONG_CODES));
                }
            }
        } catch (RuntimeException e) {
            log.warn("2FA tukenen challenge sayaci guncellenemedi userId={}: {}", userId, e.toString());
        }
    }

    /**
     * Ayni challenge icin yeni kod (sinir cagiranda: 3 / 10 dk; ayrica kod yeniden isteme beklemesi 180 sn, ihlalde
     * 429 RESEND_COOLDOWN + Retry-After). Bekleme diger kota/sinirlardan ONCE alinir: erken istekler onlari tuketmez;
     * kod gonderilemezse bekleme geri verilir. Challenge omru uzar.
     */
    public long resend(String challengeToken, Challenge ch) {
        peek(challengeToken);
        User u = users.findById(ch.userId()).orElseThrow(TwoFactorService::challengeExpired);
        String hash = Hashing.sha256(challengeToken);
        String subject = challengeSubject(u.getId(), hash);
        verification.reserveTwoFactorCooldown(subject);
        try {
            verification.requireAccountMailQuota();
            limiter.check("tf:code:user:" + u.getId(), MAX_CODE_MAILS_PER_HOUR, Duration.ofHours(1));
            verification.issueTwoFactorAfterReserve(subject, u.getEmail(), Lang.of(u.getLanguage()));
        } catch (RuntimeException e) {
            verification.releaseTwoFactorCooldown(subject);
            throw e;
        }
        redis.expire(CHALLENGE_PREFIX + hash, CHALLENGE_TTL);
        return CHALLENGE_TTL.toSeconds();
    }

    /** Kod yeniden isteme bekleme suresi (saniye); istemci geri sayim varsayilani. */
    public long resendCooldownSeconds() {
        return verification.resendCooldownSeconds();
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

    /**
     * Sifre degisimi/sifirlama/"tum cihazlardan cik": guvenilen cihazlar silinir, bekleyen etkinlestirme kodu
     * temizlenir, yeni cihaz kilidi ve tukenen challenge sayaci sifirlanir (kullanici sifreyi sifirlayarak kilidi
     * acabilir). Acik girisin challenge'lari sifre degisim isaretiyle zaten gecersizdir (bkz. {@link #peek}).
     */
    @Transactional
    public void onCredentialsChanged(Long userId) {
        devices.deleteAllForUser(userId);
        verification.clearTwoFactor(enableSubject(userId));
        redis.delete(List.of(LOCK_PREFIX + userId, EXHAUSTED_PREFIX + userId));
    }

    /**
     * Cikis-yapan-tum-oturumlar iptali (sifre degisimi/sifirlama, logout-all, yeniden kullanim tespiti, yonetici
     * oturum kapatma, erisim engeli, askiya alma): guvenilen cihazlar da gecersiz. Yalniz bir istemci turunu
     * kapatan olaylar (tek cihaz kurali) cihazlara dokunmaz.
     */
    @EventListener
    public void onSessionsRevoked(SessionsRevokedEvent e) {
        if (e.client() == null && e.userId() != null) {
            try {
                devices.deleteAllForUserInNewTx(e.userId());
            } catch (RuntimeException ex) {
                // oturum iptalini bozmaz; kayitlar 60 gunluk bosta suresiyle ve gece temizligiyle de duser
                log.warn("Guvenilen 2FA cihazlari silinemedi (user {}): {}", e.userId(), ex.toString());
            }
        }
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
        String subject = enableSubject(userId);
        verification.reserveTwoFactorCooldown(subject); // 180 sn: erken istek kota/siniri tuketmez
        try {
            verification.requireAccountMailQuota();
            limiter.check("tf:code:user:" + userId, MAX_CODE_MAILS_PER_HOUR, Duration.ofHours(1));
            verification.issueTwoFactorAfterReserve(subject, u.getEmail(), Lang.of(u.getLanguage()));
        } catch (RuntimeException e) {
            verification.releaseTwoFactorCooldown(subject);
            throw e;
        }
    }

    /** Kodu dogrular, 2FA'yi acar ve bu cihazi guvenilir yapar; kullaniciya bildirim + e-posta gider. */
    @Transactional
    public void confirmEnable(Long userId, String code, ClientContext ctx) {
        confirmEnable(userId, code, ctx, false);
    }

    /**
     * {@code closeOtherSessions}: tum oturumlar kapatilir (cagiran, bu cihaza yeni jeton cifti verir); 2FA oncesi
     * acilmis oturumlar (ornegin calinmis refresh token) bundan sonra gecersiz olur.
     */
    @Transactional
    public void confirmEnable(Long userId, String code, ClientContext ctx, boolean closeOtherSessions) {
        User u = activeUser(userId);
        if (u.isTwoFactorEnabled()) {
            throw new ApiException(HttpStatus.CONFLICT, "TWO_FACTOR_ALREADY_ENABLED",
                    "İki faktörlü doğrulama zaten açık.");
        }
        if (!verification.verifyTwoFactor(enableSubject(userId), code == null ? "" : code.trim(), scopeOf(ctx))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TWO_FACTOR_CODE_INVALID",
                    "Doğrulama kodu geçersiz veya süresi dolmuş.");
        }
        u.setTwoFactorEnabled(true);
        u.setTwoFactorEnabledAt(clock.instant());
        users.save(u);
        verification.releaseTwoFactorCooldown(enableSubject(userId)); // akis tamam: kapat/yeniden ac beklemeye takilmasin
        if (closeOtherSessions) {
            sessions.revokeAll(userId); // dinleyici guvenilen cihazlari da siler; bu cihaz asagida yeniden eklenir
        }
        if (ctx != null) {
            trust(userId, ctx.deviceHash(), ctx.platform(), ctx.appVersion());
        }
        notifier.notify(u, TwoFactorNotifier.Event.ENABLED);
    }

    /** Sifre ister; kapatinca tum guvenilen cihazlar silinir; kullaniciya bildirim + e-posta gider. */
    @Transactional
    public void disable(Long userId, String password) {
        disable(userId, password, false);
    }

    /** {@code closeOtherSessions}: tum oturumlar kapatilir (cagiran, bu cihaza yeni jeton cifti verir). */
    @Transactional
    public void disable(Long userId, String password, boolean closeOtherSessions) {
        User u = activeUser(userId);
        if (!u.isTwoFactorEnabled()) {
            throw notEnabled();
        }
        if (password == null || password.getBytes(StandardCharsets.UTF_8).length > 72
                || !encoder.matches(password, u.getPasswordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PASSWORD", "Şifre hatalı.");
        }
        if (closeOtherSessions) {
            // reset'ten ONCE: olay dinleyicisi cihazlari AYRI islemde siler; bu islem ayni satirlari silmisse kilitlenirdi
            sessions.revokeAll(userId);
        }
        reset(u);
        notifier.notify(u, TwoFactorNotifier.Event.DISABLED_BY_USER);
    }

    /**
     * Yonetici kurtarma kapatmasi (sifre istemez; gerekce/denetim/yetki cagiranda). Tum oturumlar kapatilir,
     * kullaniciya bildirim + e-posta gider. Zaten kapaliysa 409 TWO_FACTOR_NOT_ENABLED.
     */
    @Transactional
    public void forceDisable(Long userId) {
        User u = users.findById(userId).filter(x -> x.getStatus() != UserStatus.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        if (!u.isTwoFactorEnabled()) {
            throw notEnabled();
        }
        sessions.revokeAll(userId); // reset'ten ONCE (bkz. disable)
        reset(u);
        notifier.notify(u, TwoFactorNotifier.Event.DISABLED_BY_ADMIN);
    }

    private void reset(User u) {
        u.setTwoFactorEnabled(false);
        u.setTwoFactorEnabledAt(null);
        users.save(u);
        devices.deleteAllForUser(u.getId());
        verification.clearTwoFactor(enableSubject(u.getId()));
        redis.delete(List.of(LOCK_PREFIX + u.getId(), EXHAUSTED_PREFIX + u.getId()));
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

    /** Giris kodu konusu: kullanici + challenge ozeti (baska challenge'in kodu bu challenge'i gecmez). */
    static String challengeSubject(Long userId, String challengeHash) {
        return userId + ":" + challengeHash.substring(0, 32);
    }

    /** Etkinlestirme kodu konusu (giris challenge'larindan ayri). */
    static String enableSubject(Long userId) {
        return userId + ":enable";
    }

    /** Sifre/oturum iptal isareti (`pwchg:<uid>`; yoksa bos): challenge'a yazilir, dogrulamada karsilastirilir. */
    private String currentMarker(Long userId) {
        String v = redis.opsForValue().get(JwtAuthFilter.PASSWORD_CHANGED_KEY_PREFIX + userId);
        return v == null ? "" : v;
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

    /** "ay***@bingol.edu.tr": yerel kismin ilk 2 harfi (kisa adreslerde ilk harf ya da hic) + adres alani. */
    static String maskEmail(String email) {
        int at = email == null ? -1 : email.indexOf('@');
        if (at < 1) {
            return "***";
        }
        // En az bir karakter her zaman maskelenir: yerel kisim 1-2 karakterse tamami/yarisi gorunmez.
        int shown = at <= 2 ? at - 1 : 2;
        return email.substring(0, shown) + "***" + email.substring(at);
    }

    static String label(String platform, String appVersion) {
        boolean known = platform != null && !platform.isBlank() && !"UNKNOWN".equals(platform);
        if (!known && appVersion == null) {
            return null;
        }
        return ((known ? platform : "") + (appVersion != null ? (known ? " " : "") + appVersion : "")).trim();
    }

    /** uid|cihazOzeti|istemci|platform|surum|iptalIsareti (bos alan = bos metin). Alanlar '|' icermez. */
    private static String encode(Long userId, ClientContext ctx, String client, String marker) {
        return userId + "|" + nz(ctx == null ? null : ctx.deviceHash()) + "|" + nz(client) + "|"
                + nz(ctx == null ? null : ctx.platform()) + "|" + nz(ctx == null ? null : ctx.appVersion()) + "|"
                + nz(marker);
    }

    /** Eski bicim (5 alan, iptal isareti yok) da okunur: dagitim sirasinda acik challenge dusmesin. */
    private static Challenge decode(String[] f) {
        if (f.length != 5 && f.length != 6) {
            return null;
        }
        try {
            return new Challenge(Long.parseLong(f[0]), blank(f[1]), blank(f[2]), blank(f[3]), blank(f[4]));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String markerOf(String[] f) {
        return f.length == 6 ? f[5] : "";
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private static String blank(String s) {
        return s.isEmpty() ? null : s;
    }
}
