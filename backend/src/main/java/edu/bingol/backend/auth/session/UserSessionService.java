package edu.bingol.backend.auth.session;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AuthProperties;
import edu.bingol.backend.config.JwtProperties;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Cok oturum kaydi ("Cihazlarim"): her giris bir {@code sid} alir; sid access JWT'ye ve refresh kaydina konur,
 * rotasyonda korunur. Servis sozlesmesi: kayit hatasi girisi bozmaz ({@link #open} hata durumunda null doner,
 * token'lar sid'siz uretilir). Bir oturumun "acik" sayilmasi: iptal edilmemis, son kullanimi refresh omru ve
 * olusumu mutlak oturum omru icinde.
 */
@Service
public class UserSessionService {

    private static final Logger log = LoggerFactory.getLogger(UserSessionService.class);
    /** Kullanici basina listelenecek en cok acik oturum (sinirsiz sorgu yok). */
    static final int MAX_LISTED = 50;
    private static final Pattern SID = Pattern.compile("[0-9a-f]{32}");

    private final UserSessionRepository repo;
    private final ApplicationEventPublisher events;
    private final SessionService sessionService;
    private final Clock clock;
    private final Duration refreshLife;
    private final Duration absoluteLife;
    private final SecureRandom random = new SecureRandom();

    public UserSessionService(UserSessionRepository repo, ApplicationEventPublisher events,
                              SessionService sessionService, Clock clock, JwtProperties jwt, AuthProperties auth) {
        this.repo = repo;
        this.events = events;
        this.sessionService = sessionService;
        this.clock = clock;
        this.refreshLife = Duration.ofDays(Math.max(1, jwt.refreshTtlDays()));
        this.absoluteLife = Duration.ofDays(Math.max(1, auth.sessionMaxDays()));
    }

    private String newSid() {
        byte[] b = new byte[16];
        random.nextBytes(b);
        return HexFormat.of().formatHex(b);
    }

    /** Gecerli bicimde bir oturum kimligi mi (yol degiskeni dogrulamasi)? */
    public static boolean validSid(String sid) {
        return sid != null && SID.matcher(sid).matches();
    }

    /**
     * Yeni giris: kayit acar, kimligini doner (hata olursa null). `announce` true ise {@link NewSessionEvent}
     * yayinlanir (yeni cihaz bildirimi); sifre degisimi/2FA sonrasi yeniden duzenlemelerde false.
     */
    public String open(Long userId, String client, long authTimeMs, ClientContext ctx, boolean announce) {
        try {
            UserSession s = create(newSid(), userId, client, authTimeMs, ctx);
            if (announce) {
                events.publishEvent(new NewSessionEvent(userId, s.getSid(), s.getClient(), s.getPlatform(),
                        s.getDeviceName(), s.getDeviceHash(), s.getIpMasked()));
            }
            return s.getSid();
        } catch (RuntimeException e) {
            log.warn("Oturum kaydi acilamadi (user {}): {}", userId, e.toString());
            return null;
        }
    }

    private UserSession create(String sid, Long userId, String client, long authTimeMs, ClientContext ctx) {
        UserSession s = new UserSession();
        Instant now = clock.instant();
        s.setSid(sid);
        s.setUserId(userId);
        s.setClient(RefreshTokenService.normalizeClient(client));
        s.setAuthTimeMs(authTimeMs > 0 ? authTimeMs : now.toEpochMilli());
        s.setCreatedAt(authTimeMs > 0 ? Instant.ofEpochMilli(authTimeMs) : now);
        s.setLastUsedAt(now);
        if (ctx != null) {
            s.setPlatform(ctx.platform());
            s.setDeviceName(ctx.deviceName());
            s.setDeviceHash(ctx.deviceHash());
            s.setAppVersion(ctx.appVersion());
            s.setIpMasked(IpMask.of(ctx.ip()));
        }
        return repo.saveAndFlush(s);
    }

    /**
     * Refresh sirasinda: oturum kimligi varsa son kullanimi yeniler (kayit yoksa yeniden olusturur); kimlik yoksa
     * (cok oturum oncesi acilmis zincir) kayit DEVRALINIR. Kullanilacak sid'i doner (hata olursa mevcut/null).
     */
    public String refreshed(Long userId, String sid, String client, long authTimeMs, ClientContext ctx) {
        try {
            if (sid == null || sid.isBlank()) {
                return create(newSid(), userId, client, authTimeMs, ctx).getSid();
            }
            int n = repo.touch(sid, clock.instant(), ctx == null ? null : IpMask.of(ctx.ip()),
                    ctx == null ? null : ctx.appVersion());
            if (n == 0 && !repo.existsById(sid)) {
                create(sid, userId, client, authTimeMs, ctx); // gece temizliginde silinmis kayit: yeniden olustur
            }
            return sid;
        } catch (RuntimeException e) {
            log.warn("Oturum kaydi yenilenemedi (user {}): {}", userId, e.toString());
            return sid;
        }
    }

    /** Kullanicinin acik oturumlari (en son kullanilan once, en cok {@value #MAX_LISTED}). */
    public List<UserSession> active(Long userId) {
        Instant now = clock.instant();
        return repo.findActive(userId, now.minus(refreshLife), now.minus(absoluteLife), PageRequest.of(0, MAX_LISTED));
    }

    /** Baska acik oturum var mi (yeni cihaz bildirimi yalniz bu durumda anlamli). */
    public boolean hasOtherActive(Long userId, String sid) {
        Instant now = clock.instant();
        return repo.countOtherActive(userId, sid, now.minus(refreshLife), now.minus(absoluteLife)) > 0;
    }

    /** Bu cihaz ozeti kullanicinin onceki bir oturumunda goruldu mu? */
    public boolean knownDevice(Long userId, String deviceHash, String sid) {
        return deviceHash != null && repo.existsByUserIdAndDeviceHashAndSidNot(userId, deviceHash, sid);
    }

    /**
     * Bilinen cihaz mi? Cihaz ozeti varsa ozete gore; yoksa (web, X-Device-Id gondermeyen istemci) ayni istemci turu +
     * cihaz adi + maskeli IP daha once goruldu mu. Ad ya da IP yoksa bilinmeyen sayilir.
     */
    public boolean knownDevice(Long userId, String deviceHash, String client, String deviceName, String ipMasked,
                               String sid) {
        if (deviceHash != null) {
            return knownDevice(userId, deviceHash, sid);
        }
        return deviceName != null && ipMasked != null
                && repo.existsByUserIdAndClientAndDeviceNameAndIpMaskedAndSidNot(userId, client, deviceName, ipMasked, sid);
    }

    /**
     * Belirli oturumu kapatir: refresh iptal + erisim isareti + (olay ile) o cihazin push kaydi ve WebSocket'i.
     * Baskasinin oturumu ya da olmayan oturum 404 SESSION_NOT_FOUND (varlik sizmaz).
     */
    public void revoke(Long userId, String sid) {
        UserSession s = validSid(sid) ? repo.findBySidAndUserId(sid, userId).orElse(null) : null;
        if (s == null || s.getRevokedAt() != null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "SESSION_NOT_FOUND", "Oturum bulunamadı.");
        }
        sessionService.revokeSession(userId, sid);
        repo.revokeBySid(sid, clock.instant());
    }

    /** Kayit kapatilir (normal cikis, calinti tespiti). Hata cagirana sizmaz. */
    public void markRevoked(String sid) {
        if (sid == null || sid.isBlank()) {
            return;
        }
        try {
            repo.revokeBySid(sid, clock.instant());
        } catch (RuntimeException e) {
            log.warn("Oturum kaydi kapatilamadi: {}", e.toString());
        }
    }

    /** Ayni girisin (authTime) tum oturum kayitlari kapatilir (refresh ailesi iptali). */
    public void markFamilyRevoked(Long userId, long authTimeMs) {
        if (authTimeMs <= 0) {
            return;
        }
        try {
            repo.revokeByAuthTime(userId, authTimeMs, clock.instant());
        } catch (RuntimeException e) {
            log.warn("Oturum ailesi kapatilamadi (user {}): {}", userId, e.toString());
        }
    }

    /** logout-all, sifre degisimi, askiya alma (client null) ya da tek cihaz kurali (mobile): kayitlar kapanir. */
    @EventListener
    public void onSessionsRevoked(SessionsRevokedEvent e) {
        try {
            Instant now = clock.instant();
            if (e.client() == null) {
                repo.revokeAllOf(e.userId(), now);
            } else {
                repo.revokeClientOf(e.userId(), RefreshTokenService.normalizeClient(e.client()), now);
            }
        } catch (RuntimeException ex) {
            log.warn("Oturum kayitlari kapatilamadi (user {}): {}", e.userId(), ex.toString());
        }
    }
}
