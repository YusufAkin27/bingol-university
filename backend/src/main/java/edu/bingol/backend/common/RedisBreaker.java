package edu.bingol.backend.common;

import java.util.function.LongSupplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Redis devre kesici (T-003). Redis kesilince her kimlikli istek komut zaman asimini (500 ms) bekleyip Tomcat is
 * parcacigini tutuyordu; ilk hatada devre {@code app.redis.breaker-ms} (5 sn) boyunca ACILIR: bu aralikta Redis'e hic
 * gidilmeden 503 REDIS_UNAVAILABLE + Retry-After doner. Sure dolunca bir sonraki istek yeniden dener (yari acik).
 * Guvenlik tercihi korunur (fail-closed): askiya alma / rol / oturum iptali Redis'te oldugu icin Redis yokken
 * kimlikli istek GECMEZ, 503 alir.
 */
@Component
public class RedisBreaker {

    private static final Logger log = LoggerFactory.getLogger(RedisBreaker.class);

    private final long openMs;
    private final LongSupplier clock;
    private volatile long downUntil;

    @Autowired
    public RedisBreaker(@Value("${app.redis.breaker-ms:5000}") long openMs) {
        this(openMs, System::currentTimeMillis);
    }

    /** Test icin saat enjekte edilebilir. */
    public RedisBreaker(long openMs, LongSupplier clock) {
        this.openMs = Math.max(1, openMs);
        this.clock = clock;
    }

    /** Devre acik mi (Redis'e gidilmemeli)? */
    public boolean isOpen() {
        return clock.getAsLong() < downUntil;
    }

    /** Redis hatasi goruldu: devreyi {@code openMs} boyunca ac. */
    public void trip(Throwable cause) {
        boolean wasOpen = isOpen();
        downUntil = clock.getAsLong() + openMs;
        if (!wasOpen) {
            log.warn("Redis devre kesici ACILDI ({} ms): {}", openMs, cause == null ? "?" : cause.toString());
        }
    }

    /** Kalan sure (saniye, en az 1): Retry-After basligi icin. */
    public long retryAfterSeconds() {
        long left = downUntil - clock.getAsLong();
        return Math.max(1, (left + 999) / 1000);
    }

    /** Redis kaynakli bir hata mi (baglanti kopmasi, zaman asimi, istemci kapali)? Is kurali hatalari degil. */
    public static boolean isRedisFailure(Throwable t) {
        for (Throwable c = t; c != null; c = c.getCause()) {
            if (c instanceof ApiException) {
                return false;
            }
            // Sunucu cevaplari (WRONGTYPE, OOM...) RedisSystemException/RedisCommandExecutionException sayilir ve
            // devreyi ACMAZ; yalnizca baglanti kopmasi ve komut zaman asimi.
            if (c instanceof org.springframework.data.redis.RedisConnectionFailureException
                    || c instanceof io.lettuce.core.RedisConnectionException
                    || c instanceof io.lettuce.core.RedisCommandTimeoutException
                    || c instanceof io.netty.channel.ConnectTimeoutException
                    || c instanceof java.net.ConnectException
                    || c instanceof java.net.UnknownHostException) {
                return true;
            }
            if (c == c.getCause()) {
                break;
            }
        }
        return false;
    }
}
