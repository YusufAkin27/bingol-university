package edu.bingol.backend.accessban;

import java.sql.Timestamp;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Engel vurusu sayaci ve engellenen deneme gunlugu. Her istekte veritabanina YAZILMAZ: sayaclar bellekte birikir,
 * 5 sn'de bir toplu yazilir. Gunluk kaydi ayni (engel, ip) icin dakikada en fazla bir kez tutulur (saldirgan
 * trafigi tabloyu sisirmesin); sayac ise her vurusu sayar. Kuyruk doluysa gunluk kaydi dusurulur, sayac korunur.
 */
@Component
public class AccessBanHits {

    private static final Logger log = LoggerFactory.getLogger(AccessBanHits.class);
    private static final int QUEUE_SIZE = 10_000;
    private static final long LOG_THROTTLE_MS = 60_000;

    private record Attempt(Long banId, String kind, String ip, String deviceHash, Long userId, String path,
                           long atMillis) {}

    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final BlockingQueue<Attempt> queue = new ArrayBlockingQueue<>(QUEUE_SIZE);
    private final Map<Long, AtomicLong> counts = new ConcurrentHashMap<>();
    private final Map<Long, Long> lastHit = new ConcurrentHashMap<>();
    private final Map<String, Long> throttle = new ConcurrentHashMap<>();

    public AccessBanHits(JdbcTemplate jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    /** Engellenen bir isteği kaydeder (bellekte; yazim zamanlayicidadir). */
    public void record(AccessBanCache.Hit hit, ClientContext ctx, Long userId, String path) {
        long now = clock.millis();
        if (hit.banId() != null && !"ANONYMIZER".equals(hit.kind())) {
            counts.computeIfAbsent(hit.banId(), k -> new AtomicLong()).incrementAndGet();
            lastHit.put(hit.banId(), now);
        }
        String key = hit.kind() + ":" + hit.banId() + ":" + (ctx == null ? "" : ctx.ip());
        Long prev = throttle.get(key);
        if (prev != null && now - prev < LOG_THROTTLE_MS) {
            return;
        }
        if (throttle.size() > 20_000) {
            throttle.clear();
        }
        throttle.put(key, now);
        queue.offer(new Attempt("ANONYMIZER".equals(hit.kind()) ? null : hit.banId(), hit.kind(),
                ctx == null ? null : ctx.ip(), ctx == null ? null : ctx.deviceHash(), userId,
                path == null ? null : path.substring(0, Math.min(120, path.length())), now));
    }

    @Scheduled(fixedDelayString = "${app.security.ban-flush-ms:5000}")
    public void flushScheduled() {
        flush();
    }

    /** Bekleyen sayaclari ve gunluk satirlarini yazar; hata cagirana sizmaz (veri kaybi kabul edilir). */
    public void flush() {
        try {
            List<Attempt> batch = new ArrayList<>();
            queue.drainTo(batch, QUEUE_SIZE);
            if (!batch.isEmpty()) {
                jdbc.batchUpdate("INSERT INTO blocked_attempt_log (ban_id, kind, ip, device_hash, user_id, path, "
                        + "attempted_at) VALUES (?, ?, ?, ?, ?, ?, ?)", batch, 500, (ps, a) -> {
                    if (a.banId() == null) {
                        ps.setNull(1, java.sql.Types.BIGINT);
                    } else {
                        ps.setLong(1, a.banId());
                    }
                    ps.setString(2, a.kind());
                    ps.setString(3, a.ip());
                    ps.setString(4, a.deviceHash());
                    if (a.userId() == null) {
                        ps.setNull(5, java.sql.Types.BIGINT);
                    } else {
                        ps.setLong(5, a.userId());
                    }
                    ps.setString(6, a.path());
                    ps.setTimestamp(7, new Timestamp(a.atMillis()));
                });
            }
            for (Long id : new ArrayList<>(counts.keySet())) {
                AtomicLong c = counts.get(id);
                long n = c == null ? 0 : c.getAndSet(0);
                if (n > 0) {
                    Long at = lastHit.get(id);
                    jdbc.update("UPDATE access_ban SET hit_count = hit_count + ?, last_hit_at = ? WHERE id = ?", n,
                            new Timestamp(at == null ? clock.millis() : at), id);
                }
            }
        } catch (RuntimeException e) {
            log.warn("Engel vurus kayitlari yazilamadi: {}", e.toString());
        }
    }
}
