package edu.bingol.backend.auth.token;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import java.time.Clock;
import java.time.Duration;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

/**
 * Oturum iptali. {@link #revokeAll}: refresh token'lar silinir, eski access token'lar `pwchg:<uid>` isaretiyle
 * reddedilir (sifre degisimi/sifirlama, "tum cihazlardan cik"). {@link #revokeClient}: yalniz bir istemci turu
 * (tek cihaz kurali: mobil giris eski mobil oturumu kapatir); access token'in `cl` talebine gore `pwchgm:<uid>`.
 */
@Service
public class SessionService {

    private final RefreshTokenService refresh;
    private final StringRedisTemplate redis;
    private final JwtService jwt;
    private final Clock clock;
    private final ApplicationEventPublisher events;

    public SessionService(RefreshTokenService refresh, StringRedisTemplate redis, JwtService jwt, Clock clock,
                          ApplicationEventPublisher events) {
        this.refresh = refresh;
        this.redis = redis;
        this.jwt = jwt;
        this.clock = clock;
        this.events = events;
    }

    public void revokeAll(Long userId) {
        // Isaret ONCE yazilir: refresh ile yaris halinde (token tuketildi, revokeAll uyeleri okudu, yeni token
        // eklendi) yeni token'in oturum zamani isaretten eski kalir ve AuthService.refresh bunu reddeder.
        redis.opsForValue().set(JwtAuthFilter.PASSWORD_CHANGED_KEY_PREFIX + userId,
                String.valueOf(clock.millis()), jwt.accessTtl().plus(Duration.ofMinutes(1)));
        int n = refresh.revokeAll(userId);
        // Acik WebSocket baglantilari da kapansin (messaging tarafi dinler).
        events.publishEvent(new SessionsRevokedEvent(userId, null, false, n > 0));
    }

    /**
     * Oturum (authTimeMs'de acilmis) sonradan "tum cihazlardan cik"/sifre degisimi ya da (mobil icin) tek cihaz
     * kuraliyla iptal edildi mi? authTime bilinmiyorsa (eski token, 0) false: eski oturumlar kendi sureleriyle biter.
     */
    public boolean isRevokedSince(Long userId, String client, long authTimeMs) {
        if (authTimeMs <= 0) {
            return false;
        }
        if (JwtAuthFilter.tokenRevoked(authTimeMs,
                redis.opsForValue().get(JwtAuthFilter.PASSWORD_CHANGED_KEY_PREFIX + userId))) {
            return true;
        }
        return RefreshTokenService.MOBILE.equals(RefreshTokenService.normalizeClient(client))
                && JwtAuthFilter.tokenRevoked(authTimeMs,
                redis.opsForValue().get(JwtAuthFilter.MOBILE_REVOKED_KEY_PREFIX + userId));
    }

    /**
     * Yalniz `client` turundeki oturumlari kapatir. `newLogin`: tetikleyen, ayni kullanicinin yeni girisidir.
     * Yeni oturumun token'lari bu cagrindan SONRA uretilmelidir (iatms isaretten kesin buyuk olur).
     */
    public void revokeClient(Long userId, String client, boolean newLogin) {
        String c = RefreshTokenService.normalizeClient(client);
        int n = refresh.revokeClient(userId, c);
        if (RefreshTokenService.MOBILE.equals(c)) {
            redis.opsForValue().set(JwtAuthFilter.MOBILE_REVOKED_KEY_PREFIX + userId,
                    String.valueOf(clock.millis()), jwt.accessTtl().plus(Duration.ofMinutes(1)));
            // Isaret `iatms <= isaret` token'lari reddeder: 1 ms bekleyerek hemen ardindan uretilecek yeni token'in
            // iatms degerinin isaretten kesin buyuk olmasini garanti ederiz (yeni oturum kendi iptaline takilmaz).
            try {
                Thread.sleep(1);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        events.publishEvent(new SessionsRevokedEvent(userId, c, newLogin, n > 0));
    }
}
