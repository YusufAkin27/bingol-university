package edu.bingol.backend.auth.token;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import java.time.Clock;
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

/**
 * Kullanicinin tum oturumlarini kapatir: refresh token'lar silinir, eski access token'lar `pwchg:<uid>`
 * isaretiyle reddedilir. Sifre degisimi/sifirlama, "tum cihazlardan cik" gibi akislar bunu cagirir.
 */
@Service
public class SessionService {

    private final RefreshTokenService refresh;
    private final StringRedisTemplate redis;
    private final JwtService jwt;
    private final Clock clock;

    public SessionService(RefreshTokenService refresh, StringRedisTemplate redis, JwtService jwt, Clock clock) {
        this.refresh = refresh;
        this.redis = redis;
        this.jwt = jwt;
        this.clock = clock;
    }

    public void revokeAll(Long userId) {
        refresh.revokeAll(userId);
        // Isaret en uzun access token omru + pay kadar yasar; sonra eski token zaten bitmistir.
        redis.opsForValue().set(JwtAuthFilter.PASSWORD_CHANGED_KEY_PREFIX + userId,
                String.valueOf(clock.instant().getEpochSecond()), jwt.accessTtl().plus(Duration.ofMinutes(1)));
    }
}
