package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.admin.users.extras.UserExtrasDtos.SessionInfo;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.SessionList;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Yonetici icin refresh oturumu gorunumu. Redis'te `rt:<sha256>` -> `uid:client:authTimeMs` ve kullanici basina
 * `rtu:<uid>` ozet kumesi vardir (anahtar yapisi auth.token.RefreshTokenService'te; burada yalniz OKUNUR ve tek oturum
 * kapatilirken ayni sekilde silinip `rtx:` mezar tasi yazilir). Cihaz/IP bilgisi Redis'te tutulmaz, bu yuzden
 * gosterilmez. Tek oturum kapatma refresh'i keser; o oturumdan alinmis access token'lar (en cok 15 dk) suresiyle
 * biter; hemen kesmek icin "tum oturumlari kapat" kullanilir.
 */
@Service
public class AdminUserSessionService {

    private static final String TOKEN_PREFIX = "rt:";
    private static final String TOMBSTONE_PREFIX = "rtx:";
    private static final Pattern SESSION_ID = Pattern.compile("^[0-9a-f]{16}$");
    static final int ID_LEN = 16;

    private final StringRedisTemplate redis;
    private final UserRepository users;
    private final JwtProperties jwt;
    private final Clock clock;

    public AdminUserSessionService(StringRedisTemplate redis, UserRepository users, JwtProperties jwt, Clock clock) {
        this.redis = redis;
        this.users = users;
        this.jwt = jwt;
        this.clock = clock;
    }

    public SessionList list(Long userId) {
        Targets.existing(users, userId);
        Set<String> hashes = redis.opsForSet().members(userKey(userId));
        List<SessionInfo> items = new ArrayList<>();
        if (hashes != null) {
            for (String h : hashes) {
                String v = redis.opsForValue().get(TOKEN_PREFIX + h);
                if (v == null) {
                    continue; // suresi dolmus (kume uyesi bayat kalabilir)
                }
                String[] p = v.split(":", 3);
                String client = p.length < 2 ? "web" : p[1];
                long auth = p.length < 3 ? 0L : parse(p[2]);
                Long ttl = redis.getExpire(TOKEN_PREFIX + h, TimeUnit.SECONDS);
                String expires = ttl == null || ttl < 0 ? null : clock.instant().plusSeconds(ttl).toString();
                items.add(new SessionInfo(h.substring(0, Math.min(ID_LEN, h.length())), client,
                        auth > 0 ? Instant.ofEpochMilli(auth).toString() : null, expires));
            }
        }
        items.sort(Comparator.comparing(SessionInfo::createdAt, Comparator.nullsLast(Comparator.reverseOrder())));
        return new SessionList(items.size(), items);
    }

    /** Tek oturumu (refresh token'i) sonlandirir; bulunamazsa 404. */
    public void revoke(Long userId, String sessionId) {
        Targets.existing(users, userId);
        if (sessionId == null || !SESSION_ID.matcher(sessionId).matches()) {
            throw notFound();
        }
        Set<String> hashes = redis.opsForSet().members(userKey(userId));
        String match = null;
        if (hashes != null) {
            for (String h : hashes) {
                if (h.startsWith(sessionId)) {
                    match = h;
                    break;
                }
            }
        }
        if (match == null || redis.opsForValue().get(TOKEN_PREFIX + match) == null) {
            throw notFound();
        }
        redis.delete(TOKEN_PREFIX + match);
        redis.opsForSet().remove(userKey(userId), match);
        // Mezar tasi: istemci "baska yerden kapatildi" ile "suresi doldu" ayrimini yapabilsin (RefreshTokenService ile ayni)
        redis.opsForValue().set(TOMBSTONE_PREFIX + match, String.valueOf(userId),
                Duration.ofDays(Math.max(1, jwt.refreshTtlDays())));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "SESSION_NOT_FOUND", "Oturum bulunamadı.");
    }

    private static long parse(String s) {
        try {
            return Long.parseLong(s);
        } catch (NumberFormatException e) {
            return 0L;
        }
    }

    private static String userKey(Long userId) {
        return "rtu:" + userId;
    }
}
