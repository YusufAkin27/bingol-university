package edu.bingol.backend.common;

import java.util.ArrayDeque;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.LongSupplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Redis devre kesici (T-003, A01#4). Redis kesilince her kimlikli istek komut zaman asimini (500 ms) bekleyip Tomcat is
 * parcacigini tutuyordu. Tek bir yavas komut (GC, ag dalgalanmasi) tum kimlikli trafigi kesmesin diye devre kayan
 * pencerede ({@code app.redis.breaker-window-ms}, 2 sn) {@code app.redis.breaker-threshold} (3) hata gorunce ACILIR ve
 * {@code app.redis.breaker-ms} (2 sn) boyunca Redis'e hic gidilmeden 503 REDIS_UNAVAILABLE + Retry-After doner.
 *
 * <p>Sure dolunca YARI ACIK: yalniz tek bir istek (prob) Redis'e gider; basariliysa ({@link #recordSuccess}) devre
 * kapanir, basarisizsa yeniden tam sure acilir. Prob sonucu bildirmezse {@code breakerMs} sonra yeni prob verilir
 * (devre yari-acikta takili kalmaz). Prob, istegi yapan is parcacigina baglidir: ayni istek zincirinde (JwtAuthFilter ->
 * RateLimiter) sonraki {@link #isOpen} cagrilari da gecer.
 *
 * <p>Guvenlik tercihi korunur (fail-closed): askiya alma / rol / oturum iptali Redis'te oldugu icin Redis yokken
 * kimlikli istek GECMEZ, 503 alir; yalniz acilma esigi ve sure degisti.
 */
@Component
public class RedisBreaker {

    private static final Logger log = LoggerFactory.getLogger(RedisBreaker.class);

    private final long openMs;
    private final int threshold;
    private final long windowMs;
    private final LongSupplier clock;

    /** Acik/yari-acik durum; ilk esik asimindan sonra true, prob basarisina dek true kalir. */
    private volatile boolean tripped;
    private volatile long downUntil;
    /** Kapali durumdaki hata zamanlari (kayan pencere); yalniz trip() icinde, kilit altinda. */
    private final ArrayDeque<Long> failures = new ArrayDeque<>();

    private final AtomicBoolean probing = new AtomicBoolean();
    private volatile long probeStartedAt;
    private volatile long probeToken;
    private final ThreadLocal<Long> ownedProbe = new ThreadLocal<>();

    @Autowired
    public RedisBreaker(@Value("${app.redis.breaker-ms:2000}") long openMs,
                        @Value("${app.redis.breaker-threshold:3}") int threshold,
                        @Value("${app.redis.breaker-window-ms:2000}") long windowMs) {
        this(openMs, threshold, windowMs, System::currentTimeMillis);
    }

    /** Eski davranis (ilk hatada acar, 1 hata esigi); yalniz testler ve basit kullanimlar icin. */
    public RedisBreaker(long openMs) {
        this(openMs, 1, 1, System::currentTimeMillis);
    }

    /** Eski davranis (ilk hatada acar); test icin saat enjekte edilebilir. */
    public RedisBreaker(long openMs, LongSupplier clock) {
        this(openMs, 1, 1, clock);
    }

    public RedisBreaker(long openMs, int threshold, long windowMs, LongSupplier clock) {
        this.openMs = Math.max(1, openMs);
        this.threshold = Math.max(1, threshold);
        this.windowMs = Math.max(1, windowMs);
        this.clock = clock;
    }

    /**
     * Devre acik mi (Redis'e gidilmemeli)? Yari-acikta yalniz bir is parcacigi (prob) {@code false} alir; digerleri
     * prob sonuclanana dek {@code true}.
     */
    public boolean isOpen() {
        if (!tripped) {
            return false;
        }
        long now = clock.getAsLong();
        if (now < downUntil) {
            return true;
        }
        // yari acik
        Long owned = ownedProbe.get();
        if (owned != null && owned == probeToken && probing.get()) {
            return false;
        }
        if (probing.compareAndSet(false, true)) {
            startProbe(now);
            return false;
        }
        if (now - probeStartedAt > openMs && probing.get()) {
            // Onceki prob sure icinde HATA bildirmedi (her hata trip() ile bildirilir) ama basari da bildirmedi: istek
            // recordSuccess() cagirmayan bir yolda (ornegin yalniz JwtAuthFilter) bitti. Sessizlik = basari: devreyi kapat.
            recordSilentProbeSuccess();
            return false;
        }
        return true;
    }

    private void recordSilentProbeSuccess() {
        synchronized (failures) {
            if (tripped && clock.getAsLong() >= downUntil) {
                tripped = false;
                probing.set(false);
                failures.clear();
                log.info("Redis devre kesici KAPANDI (prob hata bildirmedi)");
            }
        }
    }

    private void startProbe(long now) {
        probeStartedAt = now;
        probeToken = probeToken + 1;
        ownedProbe.set(probeToken);
    }

    /** Redis hatasi goruldu. Kapaliyken esige dek sayilir; yari-acik probun hatasi devreyi yeniden acar. */
    public void trip(Throwable cause) {
        synchronized (failures) {
            long now = clock.getAsLong();
            if (tripped) {
                if (now < downUntil) {
                    return; // acikken gelen eski (in-flight) hatalar acik suresini uzatmaz
                }
                downUntil = now + openMs; // yari-acik prob basarisiz: yeniden tam sure
                probing.set(false);
                log.warn("Redis devre kesici YENIDEN ACILDI ({} ms): {}", openMs, cause == null ? "?" : cause.toString());
                return;
            }
            failures.addLast(now);
            while (!failures.isEmpty() && now - failures.peekFirst() > windowMs) {
                failures.pollFirst();
            }
            if (failures.size() >= threshold) {
                failures.clear();
                probing.set(false);
                downUntil = now + openMs;
                tripped = true;
                log.warn("Redis devre kesici ACILDI ({} ms): {}", openMs, cause == null ? "?" : cause.toString());
            } else if (log.isDebugEnabled()) {
                log.debug("Redis hatasi ({}/{}): {}", failures.size(), threshold, cause == null ? "?" : cause.toString());
            }
        }
    }

    /**
     * Basarili bir Redis komutu: yari-acikta devreyi kapatir. Acikken gelen (devre acilmadan once baslamis) isteklerin
     * basarisi devreyi kapatmaz. Kapaliyken ucuz bir okumadir.
     */
    public void recordSuccess() {
        if (!tripped) {
            return;
        }
        synchronized (failures) {
            if (tripped && clock.getAsLong() >= downUntil) {
                tripped = false;
                probing.set(false);
                failures.clear();
                log.info("Redis devre kesici KAPANDI (prob basarili)");
            }
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
