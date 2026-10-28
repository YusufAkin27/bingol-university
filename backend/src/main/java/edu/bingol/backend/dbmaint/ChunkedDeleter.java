package edu.bingol.backend.dbmaint;

import io.micrometer.core.instrument.MeterRegistry;
import java.util.HashMap;
import java.util.Map;
import java.util.function.IntSupplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Buyuk silmeleri kucuk parcalara boler: her parca KENDI islemidir (JdbcTemplate otomatik commit), boylece uzun
 * kilit, WAL patlamasi ve vacuum gecikmesi olusmaz. Parcalar arasinda kisa bekleme yazma yukunu yayar. Hata
 * cagirana sizmaz (sonraki gece kaldigi yerden devam eder).
 *
 * <p>SQL kurali: tek ifade, {@code :lim} parametresi icermeli ve en fazla :lim satir silmelidir, ornegin
 * {@code DELETE FROM t WHERE id IN (SELECT id FROM t WHERE created_at < :cutoff ORDER BY id LIMIT :lim)}.
 */
@Component
public class ChunkedDeleter {

    private static final Logger log = LoggerFactory.getLogger(ChunkedDeleter.class);

    private final NamedParameterJdbcTemplate jdbc;
    private final MeterRegistry meters;
    private final int chunkSize;
    private final long pauseMs;
    private final int maxChunks;

    public ChunkedDeleter(NamedParameterJdbcTemplate jdbc, MeterRegistry meters,
                          @Value("${app.dbmaint.chunk-size:5000}") int chunkSize,
                          @Value("${app.dbmaint.chunk-pause-ms:50}") long pauseMs,
                          @Value("${app.dbmaint.max-chunks-per-table:400}") int maxChunks) {
        this.jdbc = jdbc;
        this.meters = meters;
        this.chunkSize = Math.max(100, Math.min(chunkSize, 20_000));
        this.pauseMs = Math.max(0, pauseMs);
        this.maxChunks = Math.max(1, maxChunks);
    }

    /** @return silinen toplam satir (hata veya ust sinirda o ana kadar silinen). */
    public int delete(String name, String sql, Map<String, ?> params) {
        Map<String, Object> p = new HashMap<>();
        if (params != null) {
            p.putAll(params);
        }
        p.put("lim", chunkSize);
        return loop(name, () -> jdbc.update(sql, p));
    }

    /** Parca fonksiyonu silinen satiri doner; chunkSize'dan azsa durur. */
    int loop(String name, IntSupplier chunk) {
        int total = 0;
        try {
            for (int i = 0; i < maxChunks; i++) {
                int n = chunk.getAsInt();
                total += n;
                if (n < chunkSize) {
                    break;
                }
                if (pauseMs > 0) {
                    Thread.sleep(pauseMs);
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (RuntimeException e) {
            log.warn("dbmaint {} parcali silme hatasi (o ana kadar {} satir): {}", name, total, e.toString());
        }
        if (total > 0) {
            meters.counter("bu_dbmaint_deleted_total", "table", name).increment(total);
            log.info("dbmaint {}: {} satir silindi", name, total);
        }
        return total;
    }

    public int chunkSize() {
        return chunkSize;
    }
}
