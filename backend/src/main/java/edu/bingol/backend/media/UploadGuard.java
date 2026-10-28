package edu.bingol.backend.media;

import edu.bingol.backend.common.ApiException;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Yükleme (medya/video) koruması: heap + tmpfs tükenmesiyle DoS'u ve depolamanın sınırsız şişmesini önler.
 * <ul>
 *   <li><b>Eşzamanlılık:</b> yalnız AĞIR (video) yüklemeler için işlem içi {@link Semaphore}
 *       ({@code app.media.max-concurrent-uploads}, varsayılan 3; dolu = hemen 429 UPLOAD_BUSY) ve her kullanıcı için
 *       aynı anda 1 yükleme ({@code app.media.max-concurrent-per-user}). Kullanıcı kilidi Redis INCR ile
 *       örnekler arası atomiktir (Redis yoksa bellek içi); bu, "bekleyen medya sınırı" kontrolü ile kaydın
 *       arasındaki yarışı da kapatır. Sıralı istemciler kısa süre bekletilir, paralel olanlar sıraya girer.</li>
 *   <li><b>Günlük kota:</b> kullanıcı başına yükleme sayısı ve bayt üst sınırı ({@code app.media.max-uploads-per-day},
 *       {@code app.media.max-bytes-per-day}); aşılınca 429 UPLOAD_QUOTA_EXCEEDED.</li>
 * </ul>
 * Servis sözleşmesi: Redis erişilemezse bellek içi yedek kullanılır, istisna sızdırılmaz.
 */
@Component
public class UploadGuard {

    private static final Logger log = LoggerFactory.getLogger(UploadGuard.class);
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final Duration LOCK_TTL = Duration.ofMinutes(3);

    /** Serbest bırakılabilir izin; kapatmak (try-with-resources) kilitleri geri verir. */
    public interface Permit extends AutoCloseable {
        @Override
        void close();
    }

    private static final Permit NOOP = () -> { };

    private final StringRedisTemplate redis;
    private final Semaphore heavy;
    private final long userWaitMs;
    private final int maxPerDay;
    private final long maxBytesPerDay;
    private final ConcurrentHashMap<Long, Semaphore> localUser = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, AtomicLong> localDaily = new ConcurrentHashMap<>();

    @Autowired
    public UploadGuard(ObjectProvider<StringRedisTemplate> redis,
                       @Value("${app.media.max-concurrent-uploads:3}") int maxConcurrent,
                       @Value("${app.media.user-wait-ms:5000}") long userWaitMs,
                       @Value("${app.media.max-uploads-per-day:300}") int maxPerDay,
                       @Value("${app.media.max-bytes-per-day:838860800}") long maxBytesPerDay) {
        this(redis.getIfAvailable(), maxConcurrent, userWaitMs, maxPerDay, maxBytesPerDay);
    }

    /** Test/dogrudan kurucu (redis null = yalniz bellek ici). */
    public UploadGuard(StringRedisTemplate redis, int maxConcurrent, long userWaitMs, int maxPerDay,
                       long maxBytesPerDay) {
        this.redis = redis;
        this.heavy = new Semaphore(Math.max(1, maxConcurrent));
        this.userWaitMs = Math.max(0, userWaitMs);
        this.maxPerDay = maxPerDay;
        this.maxBytesPerDay = maxBytesPerDay;
    }

    /**
     * Kullanıcı başına tek yükleme kilidi (gerekirse kısa süre bekler) + ağır yüklemelerde genel eşzamanlılık
     * sınırı. Alınamazsa 429 UPLOAD_BUSY. Dönen izin mutlaka kapatılmalıdır.
     */
    public Permit acquire(Long userId, boolean heavyUpload) {
        if (userId == null) {
            return NOOP;
        }
        Permit user = acquireUser(userId);
        if (!heavyUpload) {
            return user;
        }
        if (!heavy.tryAcquire()) {
            user.close();
            throw busy();
        }
        return () -> {
            heavy.release();
            user.close();
        };
    }

    /** Şu an kaç ağır yükleme izni boş (test/izleme). */
    public int availableHeavy() {
        return heavy.availablePermits();
    }

    private Permit acquireUser(long userId) {
        String key = "upl:busy:" + userId;
        long deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(userWaitMs);
        if (redis != null) {
            try {
                while (true) {
                    Long n = redis.opsForValue().increment(key);
                    if (n != null && n == 1) {
                        redis.expire(key, LOCK_TTL);
                        return () -> release(key);
                    }
                    release(key); // bu denemenin artisini geri al
                    if (System.nanoTime() >= deadline) {
                        throw busy();
                    }
                    sleep(100);
                }
            } catch (ApiException e) {
                throw e;
            } catch (RuntimeException e) {
                log.debug("Yukleme kilidi Redis'te alinamadi, bellek ici yedek: {}", e.toString());
            }
        }
        Semaphore s = localUser.computeIfAbsent(userId, k -> new Semaphore(1));
        try {
            if (!s.tryAcquire(userWaitMs, TimeUnit.MILLISECONDS)) {
                throw busy();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw busy();
        }
        return () -> {
            s.release();
            if (localUser.size() > 10_000) {
                localUser.entrySet().removeIf(en -> en.getValue().availablePermits() == 1);
            }
        };
    }

    private void release(String key) {
        try {
            Long n = redis.opsForValue().decrement(key);
            if (n != null && n <= 0) {
                redis.delete(key);
            }
        } catch (RuntimeException e) {
            log.debug("Yukleme kilidi birakilamadi (TTL ile dusecek): {}", e.toString());
        }
    }

    /**
     * Günlük kullanıcı kotası: bu yükleme (1 adet, `bytes` bayt) sayıyı veya bayt toplamını aşıyorsa 429
     * UPLOAD_QUOTA_EXCEEDED. Sayaçlar atomik INCR/INCRBY ile artırılır (paralel isteklerde yarış yok).
     */
    public void charge(Long userId, long bytes) {
        if (userId == null) {
            return;
        }
        String day = LocalDate.now(ZONE).toString();
        long count = add("upl:cnt:" + userId + ":" + day, 1);
        long total = add("upl:bytes:" + userId + ":" + day, Math.max(0, bytes));
        if ((maxPerDay > 0 && count > maxPerDay) || (maxBytesPerDay > 0 && total > maxBytesPerDay)) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "UPLOAD_QUOTA_EXCEEDED",
                    "Günlük yükleme kotanıza ulaştınız. Lütfen yarın tekrar deneyin.");
        }
    }

    private long add(String key, long delta) {
        if (redis != null) {
            try {
                Long n = redis.opsForValue().increment(key, delta);
                if (n != null) {
                    if (n == delta) {
                        redis.expire(key, Duration.ofDays(2));
                    }
                    return n;
                }
            } catch (RuntimeException e) {
                log.debug("Yukleme kotasi Redis'e yazilamadi, bellek ici yedek: {}", e.toString());
            }
        }
        if (localDaily.size() > 20_000) {
            localDaily.clear();
        }
        return localDaily.computeIfAbsent(key, k -> new AtomicLong()).addAndGet(delta);
    }

    private static ApiException busy() {
        return new ApiException(HttpStatus.TOO_MANY_REQUESTS, "UPLOAD_BUSY",
                "Başka bir yüklemeniz sürüyor veya sunucu yoğun. Lütfen biraz bekleyip tekrar deneyin.");
    }

    private static void sleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw busy();
        }
    }
}
