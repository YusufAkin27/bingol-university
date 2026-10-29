package edu.bingol.backend.config;

import edu.bingol.backend.common.RateLimitedException;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Parola özetleme (bcrypt) için eşzamanlılık bölmesi (bulkhead). Yük testi bulgusu: 500 eşzamanlı giriş her çekirdeği
 * bcrypt ile doldurup aynı anda okuma isteklerini 4-6 sn geciktiriyordu. Aynı anda en çok {@code permits} özetleme
 * çalışır (varsayılan çekirdek-1: en az bir çekirdek diğer trafiğe kalır). Sıra da sınırlıdır: en çok {@code maxQueue}
 * istek bekler (bekleyen istek bir Tomcat iş parçacığı tutar; sınırsız sıra iş parçacığı havuzunu tüketip tüm trafiği
 * durdururdu), fazlası ya da {@code waitMs} içinde sırası gelmeyen anında 429 + {@code Retry-After} alır; istemci geri
 * çekilip yeniden dener. Ayarlar: {@code app.security.password-hash-concurrency|-max-queue|-wait-ms}.
 */
public class BoundedPasswordEncoder implements PasswordEncoder {

    /** Reddedilen istemciye önerilen bekleme (sn). */
    static final long RETRY_AFTER_SECONDS = 3;

    private final PasswordEncoder delegate;
    private final Semaphore permits;
    private final int maxQueue;
    private final long waitMs;
    private final AtomicInteger waiting = new AtomicInteger();

    public BoundedPasswordEncoder(PasswordEncoder delegate, int permits, int maxQueue, long waitMs) {
        this.delegate = delegate;
        this.permits = new Semaphore(Math.max(1, permits), true);
        this.maxQueue = Math.max(0, maxQueue);
        this.waitMs = waitMs;
    }

    @Override
    public String encode(CharSequence rawPassword) {
        acquire();
        try {
            return delegate.encode(rawPassword);
        } finally {
            permits.release();
        }
    }

    @Override
    public boolean matches(CharSequence rawPassword, String encodedPassword) {
        acquire();
        try {
            return delegate.matches(rawPassword, encodedPassword);
        } finally {
            permits.release();
        }
    }

    @Override
    public boolean upgradeEncoding(String encodedPassword) {
        return delegate.upgradeEncoding(encodedPassword);
    }

    private void acquire() {
        if (permits.tryAcquire()) {
            return; // hızlı yol: boşta izin var
        }
        if (waiting.incrementAndGet() > maxQueue) {
            waiting.decrementAndGet();
            throw busy();
        }
        try {
            if (!permits.tryAcquire(waitMs, TimeUnit.MILLISECONDS)) {
                throw busy();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw busy();
        } finally {
            waiting.decrementAndGet();
        }
    }

    private static RateLimitedException busy() {
        return new RateLimitedException(RETRY_AFTER_SECONDS);
    }

    /** Boşta izin sayısı (test/izleme). */
    int availablePermits() {
        return permits.availablePermits();
    }

    /** Sırada bekleyen istek sayısı (test/izleme). */
    int waitingCount() {
        return waiting.get();
    }
}
