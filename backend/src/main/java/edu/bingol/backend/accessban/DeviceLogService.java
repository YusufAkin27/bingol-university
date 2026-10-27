package edu.bingol.backend.accessban;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.ArrayBlockingQueue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/**
 * Kullanicinin gorulen cihaz+IP kaydi (`user_device_log`). REGISTER/LOGIN/REFRESH aninda senkron, normal istekte
 * (REQUEST) ayni (kullanici, cihaz, ip) icin 30 dakikada en fazla bir kez ve asenkron yazilir. Hata hicbir zaman
 * istegi bozmaz. Kayitlar 90 gun sonra silinir ({@link AccessBanRetentionJob}).
 */
@Service
public class DeviceLogService {

    private static final Logger log = LoggerFactory.getLogger(DeviceLogService.class);
    private static final long REQUEST_THROTTLE_MS = 30 * 60_000L;

    private final UserDeviceLogRepository repo;
    private final Clock clock;
    private final Map<String, Long> recent = new ConcurrentHashMap<>();
    private final ExecutorService async = new ThreadPoolExecutor(1, 1, 30, TimeUnit.SECONDS,
            new ArrayBlockingQueue<>(2000), r -> {
                Thread t = new Thread(r, "device-log");
                t.setDaemon(true);
                return t;
            }, new ThreadPoolExecutor.DiscardPolicy());

    public DeviceLogService(UserDeviceLogRepository repo, Clock clock) {
        this.repo = repo;
        this.clock = clock;
    }

    /** Olay: REGISTER | LOGIN | REFRESH | REQUEST. */
    public void record(Long userId, ClientContext ctx, String event) {
        if (userId == null || ctx == null || ctx.ip() == null) {
            return;
        }
        try {
            upsert(userId, ctx, event);
        } catch (RuntimeException e) {
            log.warn("Cihaz kaydi yazilamadi (user {}): {}", userId, e.toString());
        }
    }

    /** Normal istek: kisitli ve asenkron. */
    public void touch(Long userId, ClientContext ctx) {
        if (userId == null || ctx == null || ctx.ip() == null) {
            return;
        }
        String key = userId + "|" + ctx.deviceHash() + "|" + ctx.ip();
        long now = clock.millis();
        Long prev = recent.get(key);
        if (prev != null && now - prev < REQUEST_THROTTLE_MS) {
            return;
        }
        if (recent.size() > 50_000) {
            recent.clear();
        }
        recent.put(key, now);
        try {
            async.execute(() -> record(userId, ctx, "REQUEST"));
        } catch (RejectedExecutionException e) {
            // kuyruk dolu: bu kayit atlanir
        }
    }

    private void upsert(Long userId, ClientContext ctx, String event) {
        String hash = ctx.deviceHash() == null ? UserDeviceLog.NO_DEVICE : ctx.deviceHash();
        try {
            apply(userId, hash, ctx, event);
        } catch (DataIntegrityViolationException e) {
            apply(userId, hash, ctx, event); // es zamanli ekleme: ikinci denemede guncellenir
        }
    }

    private void apply(Long userId, String hash, ClientContext ctx, String event) {
        Instant now = clock.instant();
        long[] k = IpRanges.keyOf(ctx.ip());
        if (k == null) {
            return; // cozumlenemeyen adres (unknown) kaydedilmez
        }
        String ip = IpRanges.text(k[0], k[1]); // kanonik metin: ayni adres tek satir
        UserDeviceLog row = repo.findByUserIdAndDeviceHashAndIp(userId, hash, ip).orElse(null);
        if (row == null) {
            row = new UserDeviceLog();
            row.setUserId(userId);
            row.setDeviceHash(hash);
            row.setIp(ip);
            row.setIpFamily((short) IpRanges.family(k[0], k[1]));
            row.setFirstSeenAt(now);
        } else {
            row.setSeenCount(row.getSeenCount() + 1);
        }
        row.setPlatform(ctx.platform() == null ? "UNKNOWN" : ctx.platform());
        if (ctx.appVersion() != null) {
            row.setAppVersion(ctx.appVersion());
        }
        row.setLastSeenAt(now);
        row.setLastEvent(event);
        repo.save(row);
    }
}
