package edu.bingol.backend.dbmaint;

import io.micrometer.core.instrument.MeterRegistry;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;
import java.util.function.LongConsumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Buyuk silmeleri kucuk parcalara boler: her parca KENDI islemidir (otomatik commit ya da asagidaki kisa islem),
 * boylece uzun kilit, WAL patlamasi ve vacuum gecikmesi olusmaz. Parcalar arasinda kisa bekleme yazma yukunu yayar.
 * Hata cagirana sizmaz (sonraki gece kaldigi yerden devam eder) ANCAK sayilir: {@code bu_dbmaint_chunk_failed_total}
 * ve {@link #failedChunks()} (T-071: eskiden hata yutulunca tablo hic temizlenmiyor ama kimse fark etmiyordu).
 *
 * <p>T-071 (A2-08): 8 sn'lik {@code statement_timeout} ile 5000'lik bildirim parcasi (5,4 sn) arasindaki pay dardi;
 * IO baskisinda parca iptal olur ve tablo o gece hic temizlenmezdi. Artik (a) PostgreSQL'de her parca kendi kisa
 * isleminde {@code SET LOCAL statement_timeout} (varsayilan 60 sn) ile calisir (yalniz bakim parcasi; normal API
 * baglantilari 8 sn kalir), (b) bildirim/mail gibi indeksi cok tablolar {@link #deleteHeavy} ile daha kucuk
 * parcalarla silinir.
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
    private final int heavyChunkSize;
    private final long pauseMs;
    private final int maxChunks;
    private final long statementTimeoutMs;
    private final AtomicLong failedChunks = new AtomicLong();

    /** Birim testleri / eski cagrilar: parca zaman asimi ayari yok (baglanti varsayilani), agir parca = normal parca. */
    public ChunkedDeleter(NamedParameterJdbcTemplate jdbc, MeterRegistry meters, int chunkSize, long pauseMs,
                          int maxChunks) {
        this(jdbc, meters, chunkSize, pauseMs, maxChunks, chunkSize, 0);
    }

    @Autowired
    public ChunkedDeleter(NamedParameterJdbcTemplate jdbc, MeterRegistry meters,
                          @Value("${app.dbmaint.chunk-size:5000}") int chunkSize,
                          @Value("${app.dbmaint.chunk-pause-ms:50}") long pauseMs,
                          @Value("${app.dbmaint.max-chunks-per-table:400}") int maxChunks,
                          @Value("${app.dbmaint.heavy-chunk-size:2000}") int heavyChunkSize,
                          @Value("${app.dbmaint.statement-timeout-ms:60000}") long statementTimeoutMs) {
        this.jdbc = jdbc;
        this.meters = meters;
        this.chunkSize = Math.max(100, Math.min(chunkSize, 20_000));
        this.heavyChunkSize = Math.max(100, Math.min(heavyChunkSize, this.chunkSize));
        this.pauseMs = Math.max(0, pauseMs);
        this.maxChunks = Math.max(1, maxChunks);
        this.statementTimeoutMs = Math.max(0, statementTimeoutMs);
    }

    /** @return silinen toplam satir (hata veya ust sinirda o ana kadar silinen). */
    public int delete(String name, String sql, Map<String, ?> params) {
        return delete(name, chunkSize, sql, params);
    }

    /**
     * Cok indeksli tablolar (bildirim: 8 indeks, ~1 ms/satir) icin daha kucuk parca: bir parca suresi zaman asimi
     * sinirindan uzak kalir. Diger kurallar {@link #delete} ile aynidir.
     */
    public int deleteHeavy(String name, String sql, Map<String, ?> params) {
        return delete(name, heavyChunkSize, sql, params);
    }

    private int delete(String name, int size, String sql, Map<String, ?> params) {
        Map<String, Object> p = new HashMap<>();
        if (params != null) {
            p.putAll(params);
        }
        p.put("lim", size);
        return loop(name, size, () -> exec(sql, p));
    }

    /** Parca fonksiyonu silinen satiri doner; chunkSize'dan azsa durur. */
    int loop(String name, IntSupplier chunk) {
        return loop(name, chunkSize, chunk);
    }

    private int loop(String name, int size, IntSupplier chunk) {
        int total = 0;
        try {
            for (int i = 0; i < maxChunks; i++) {
                int n = chunk.getAsInt();
                total += n;
                if (n < size) {
                    break;
                }
                if (pauseMs > 0) {
                    Thread.sleep(pauseMs);
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (RuntimeException e) {
            chunkFailed(name);
            log.warn("dbmaint {} parcali silme hatasi (o ana kadar {} satir): {}", name, total, e.toString());
        }
        if (total > 0) {
            meters.counter("bu_dbmaint_deleted_total", "table", name).increment(total);
            log.info("dbmaint {}: {} satir silindi", name, total);
        }
        return total;
    }

    private void chunkFailed(String name) {
        failedChunks.incrementAndGet();
        try {
            meters.counter("bu_dbmaint_chunk_failed_total", "table", name).increment();
        } catch (RuntimeException ignored) {
            // metrik hatasi bakimi bozmaz
        }
    }

    /** Process basindan beri basarisiz olan parca sayisi (cagiran once/sonra farkina bakar; T-071). */
    public long failedChunks() {
        return failedChunks.get();
    }

    /**
     * Tek parcayi calistirir. PostgreSQL'de ve cagiran bir islem acik degilse parca KENDI kisa isleminde
     * {@code SET LOCAL statement_timeout} ile calisir (SET LOCAL commit/rollback'te kendiliginden geri alinir; havuz
     * baglantisina sizmaz). Aksi halde (H2 testleri, zaman asimi ayari 0, acik islem) duz otomatik-commit guncelleme.
     */
    private int exec(String sql, Map<String, Object> p) {
        if (statementTimeoutMs <= 0 || TransactionSynchronizationManager.isActualTransactionActive()) {
            return jdbc.update(sql, p);
        }
        return jdbc.getJdbcTemplate().execute((ConnectionCallback<Integer>) con -> chunkOnConnection(con, sql, p));
    }

    private int chunkOnConnection(Connection con, String sql, Map<String, Object> p) throws SQLException {
        NamedParameterJdbcTemplate same = new NamedParameterJdbcTemplate(new SingleConnectionDataSource(con, true));
        if (!"PostgreSQL".equalsIgnoreCase(con.getMetaData().getDatabaseProductName())) {
            return same.update(sql, p);
        }
        boolean auto = con.getAutoCommit();
        con.setAutoCommit(false);
        try {
            try (Statement st = con.createStatement()) {
                st.execute("SET LOCAL statement_timeout = " + statementTimeoutMs); // sayi, kullanici girdisi degil
            }
            int n = same.update(sql, p);
            con.commit();
            return n;
        } catch (SQLException | RuntimeException e) {
            try {
                con.rollback();
            } catch (SQLException ignored) {
                // asil hata yayilir
            }
            throw e;
        } finally {
            try {
                con.setAutoCommit(auto);
            } catch (SQLException ignored) {
                // baglanti bozuksa havuz zaten atar
            }
        }
    }

    /** {@link #deleteAll} sonucu: silinen toplam satir ve (varsa) hata metni; hata cagirana firlatilmaz. */
    public record Result(long deleted, String error, boolean cancelled) {
    }

    /**
     * Elle (yonetici) temizlik: gece isinin parca ust sinirina takilmaz, her parcadan sonra {@code progress} toplam
     * silinen sayiyla cagrilir. Hata yutulmaz, sonuc icinde doner (cagiran durumu kayda yazar). Guvenlik ust siniri
     * 200 000 parca (~1 milyar satir). SQL kurali {@link #delete} ile aynidir.
     */
    public Result deleteAll(String name, String sql, Map<String, ?> params, LongConsumer progress, BooleanSupplier cancel) {
        Map<String, Object> p = new HashMap<>();
        if (params != null) {
            p.putAll(params);
        }
        p.put("lim", chunkSize);
        long total = 0;
        String error = null;
        boolean cancelled = false;
        try {
            for (int i = 0; i < 200_000; i++) {
                if (cancel != null && cancel.getAsBoolean()) {
                    cancelled = true;
                    break;
                }
                int n = exec(sql, p);
                total += n;
                if (progress != null) {
                    progress.accept(total);
                }
                if (n < chunkSize) {
                    break;
                }
                if (pauseMs > 0) {
                    Thread.sleep(pauseMs);
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            error = "interrupted";
        } catch (RuntimeException e) {
            chunkFailed(name);
            log.warn("dbmaint {} elle silme hatasi (o ana kadar {} satir): {}", name, total, e.toString());
            error = e.getClass().getSimpleName();
        }
        if (total > 0) {
            meters.counter("bu_dbmaint_deleted_total", "table", name).increment(total);
            log.info("dbmaint {}: {} satir silindi (elle)", name, total);
        }
        return new Result(total, error, cancelled);
    }

    public int chunkSize() {
        return chunkSize;
    }

    /** Agir (cok indeksli) tablolar icin parca boyutu. */
    public int heavyChunkSize() {
        return heavyChunkSize;
    }
}
