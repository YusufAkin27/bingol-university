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
import org.springframework.beans.factory.annotation.Value;
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
    /** Kullanici basina saatte en cok bu kadar YENI (kullanici,cihaz,ip) anahtari yazilmaya calisilir. */
    private static final int NEW_KEYS_PER_HOUR = 30;
    private final Map<Long, long[]> newKeyWindow = new ConcurrentHashMap<>();

    /** Kullanici basina en cok farkli cihaz ozeti (X-Device-Id dondurme saldirisina karsi); satir siniri bunun 4 kati. */
    @Value("${app.security.max-devices-per-user:50}")
    private int maxDevicesPerUser = 50;
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
            // Once suresi dolmus girdileri at; hala doluysa (saldiri) sifirla
            recent.values().removeIf(t -> now - t >= REQUEST_THROTTLE_MS);
            if (recent.size() > 50_000) {
                recent.clear();
            }
        }
        if (prev == null && tooManyNewKeys(userId, now)) {
            return; // cihaz/IP dondurerek tabloyu sisirme girisimi: kullanici basina saatlik yeni anahtar siniri
        }
        recent.put(key, now);
        try {
            async.execute(() -> record(userId, ctx, "REQUEST"));
        } catch (RejectedExecutionException e) {
            // kuyruk dolu: bu kayit atlanir
        }
    }

    /** Kullanicinin bu saatteki yeni anahtar sayisi siniri astiysa true. */
    private boolean tooManyNewKeys(Long userId, long now) {
        if (newKeyWindow.size() > 50_000) {
            newKeyWindow.clear();
        }
        long[] w = newKeyWindow.compute(userId, (k, cur) -> {
            if (cur == null || now - cur[0] >= 3_600_000L) {
                return new long[] {now, 1};
            }
            cur[1]++;
            return cur;
        });
        return w[1] > NEW_KEYS_PER_HOUR;
    }

    void setMaxDevicesPerUser(int n) {
        this.maxDevicesPerUser = n;
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
            // Kullanici basina sinir: asilirsa en eski satir YENI cihaza/IP'ye devredilir (tablo buyumez)
            row = overCap(userId, hash) ? repo.findFirstByUserIdOrderByLastSeenAtAsc(userId).orElse(null) : null;
            if (row != null) {
                row.setSeenCount(1);
            } else {
                row = new UserDeviceLog();
                row.setUserId(userId);
            }
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

    /** Yeni satir eklemek siniri asar mi (farkli cihaz sayisi veya toplam satir). */
    private boolean overCap(Long userId, String hash) {
        if (maxDevicesPerUser <= 0) {
            return false;
        }
        if (repo.countByUserId(userId) >= (long) maxDevicesPerUser * 4) {
            return true;
        }
        return !repo.existsByUserIdAndDeviceHash(userId, hash) && repo.countDistinctDevices(userId) >= maxDevicesPerUser;
    }
}
