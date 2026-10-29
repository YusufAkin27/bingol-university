package edu.bingol.backend.dbmaint.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.dbmaint.ChunkedDeleter;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.PurgeView;
import edu.bingol.backend.dbmaint.admin.RetentionTables.Spec;
import java.sql.Types;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Onayli elle temizlik. Cagri aninda kayit (RUNNING, {@code data_purge_log}) yazilir ve is ARKA PLANDA tek is
 * parcacigiyla yurur ({@link ChunkedDeleter#deleteAll}: parcali, her parca ayri islem). Ayni anda tek temizlik
 * (kayit nabzi + {@link SchedulerLock}). Silinen aralik yalniz asgari saklama suresinden eski kayitlardir.
 * Her parcadan sonra nabiz/sayac guncellenir; surec olurse kayit {@code INTERRUPTED} olur (bkz. {@link #markStale}).
 */
@Service
public class RetentionPurgeService {

    private static final Logger log = LoggerFactory.getLogger(RetentionPurgeService.class);
    /** Bu surede nabiz atmayan RUNNING kaydi olu sayilir. */
    static final Duration STALE_AFTER = Duration.ofMinutes(10);

    private final NamedParameterJdbcTemplate jdbc;
    private final DataPurgeLogRepository logs;
    private final ChunkedDeleter deleter;
    private final SchedulerLock lock;
    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "retention-purge");
        t.setDaemon(true);
        return t;
    });
    private final long lockHours;

    public RetentionPurgeService(NamedParameterJdbcTemplate jdbc, DataPurgeLogRepository logs, ChunkedDeleter deleter,
                                 SchedulerLock lock,
                                 @Value("${app.retention.purge-lock-hours:6}") long lockHours) {
        this.jdbc = jdbc;
        this.logs = logs;
        this.deleter = deleter;
        this.lock = lock;
        this.lockHours = Math.max(1, lockHours);
    }

    @jakarta.annotation.PreDestroy
    void shutdown() {
        executor.shutdownNow();
    }

    /** Kaydi yazar ve isi baslatir; 202 icin kaydi doner. */
    public PurgeView start(Spec spec, RetentionService.Range range, DataExportReceipt receipt, boolean forced,
                           long estRows, String reason, Long adminId, String adminEmail, String requestId) {
        if (logs.existsLive(Instant.now().minus(STALE_AFTER))) {
            throw new ApiException(HttpStatus.CONFLICT, "RETENTION_PURGE_RUNNING",
                    "Başka bir temizlik sürüyor; bitmesini bekleyin.");
        }
        DataPurgeLog row = new DataPurgeLog();
        row.setTableName(spec.name());
        row.setRangeFrom(range.from());
        row.setRangeTo(range.toExclusive());
        row.setReceiptId(receipt == null ? null : receipt.getId());
        row.setForced(forced);
        row.setEstRows(estRows);
        row.setReason(reason.length() > 300 ? reason.substring(0, 300) : reason);
        row.setAdminId(adminId);
        row.setAdminEmail(adminEmail);
        row.setRequestId(requestId);
        row = logs.save(row);
        long id = row.getId();
        executor.execute(() -> run(id, spec, range));
        return view(row);
    }

    /** Is parcacigi govdesi. Hicbir istisna disari sizmaz; sonuc kayda yazilir. */
    void run(long id, Spec spec, RetentionService.Range range) {
        boolean ran = false;
        try {
            ran = lock.tryRun("retention-purge", Duration.ofHours(lockHours), () -> doPurge(id, spec, range));
        } catch (RuntimeException e) {
            finish(id, DataPurgeLog.Status.FAILED, e.getClass().getSimpleName());
            return;
        }
        if (!ran) {
            finish(id, DataPurgeLog.Status.FAILED, "LOCK_UNAVAILABLE");
        }
    }

    private void doPurge(long id, Spec spec, RetentionService.Range range) {
        try {
            Map<String, Object> p = new HashMap<>(range.params());
            bounds(id, spec, p);
            String sql = "DELETE FROM " + spec.name() + " WHERE " + spec.keyColumn() + " IN (SELECT "
                    + spec.keyColumn() + " FROM " + spec.name() + " WHERE " + spec.rangeWhere() + " ORDER BY "
                    + spec.keyColumn() + " LIMIT :lim)";
            ChunkedDeleter.Result r = deleter.deleteAll("retention_" + spec.name(), sql, p,
                    total -> heartbeat(id, total), () -> Thread.currentThread().isInterrupted());
            try {
                jdbc.getJdbcTemplate().execute("ANALYZE " + spec.name());
            } catch (RuntimeException e) {
                log.debug("ANALYZE atlandi ({}): {}", spec.name(), e.toString());
            }
            jdbc.update("UPDATE data_purge_log SET deleted_rows = :n WHERE id = :id", Map.of("n", r.deleted(), "id", id));
            finish(id, r.error() == null ? DataPurgeLog.Status.COMPLETED : DataPurgeLog.Status.FAILED, r.error());
        } catch (RuntimeException e) {
            log.warn("Temizlik basarisiz ({} kayit {}): {}", spec.name(), id, e.toString());
            finish(id, DataPurgeLog.Status.FAILED, e.getClass().getSimpleName());
        }
    }

    /** Aralikta en eski/en yeni kayit zamani (en iyi gayret; okunamazsa bos). */
    private void bounds(long id, Spec spec, Map<String, Object> p) {
        try {
            String base = "SELECT " + spec.timeColumn() + " FROM " + spec.name() + " WHERE " + spec.rangeWhere()
                    + " ORDER BY " + spec.keyColumn();
            OffsetDateTime oldest = first(base + " ASC LIMIT 1", p);
            OffsetDateTime newest = first(base + " DESC LIMIT 1", p);
            jdbc.update("UPDATE data_purge_log SET oldest_at = :o, newest_at = :n WHERE id = :id",
                    new MapSqlParameterSource("id", id)
                            .addValue("o", oldest, Types.TIMESTAMP_WITH_TIMEZONE)
                            .addValue("n", newest, Types.TIMESTAMP_WITH_TIMEZONE));
        } catch (RuntimeException e) {
            log.debug("Silinen aralik siniri okunamadi: {}", e.toString());
        }
    }

    private OffsetDateTime first(String sql, Map<String, Object> p) {
        List<OffsetDateTime> r = jdbc.query(sql, p, (rs, i) -> rs.getObject(1, OffsetDateTime.class));
        return r.isEmpty() ? null : r.get(0);
    }

    private void heartbeat(long id, long total) {
        try {
            jdbc.update("UPDATE data_purge_log SET deleted_rows = :n, updated_at = now() WHERE id = :id",
                    Map.of("n", total, "id", id));
        } catch (RuntimeException e) {
            log.debug("Temizlik nabzi yazilamadi: {}", e.toString());
        }
    }

    private void finish(long id, DataPurgeLog.Status status, String error) {
        try {
            jdbc.update("UPDATE data_purge_log SET status = :s, error = :e, finished_at = now(), updated_at = now() "
                            + "WHERE id = :id",
                    new MapSqlParameterSource("id", id).addValue("s", status.name())
                            .addValue("e", error, Types.VARCHAR));
        } catch (RuntimeException e) {
            log.warn("Temizlik sonucu yazilamadi (kayit {}): {}", id, e.toString());
        }
    }

    /** Nabzi kesilmis RUNNING kayitlarini INTERRUPTED yapar (periyodik is + acilis). */
    public int markStale() {
        try {
            Instant now = Instant.now();
            return logs.markStale(now.minus(STALE_AFTER), now);
        } catch (RuntimeException e) {
            log.debug("Bayat temizlik kayitlari isaretlenemedi: {}", e.toString());
            return 0;
        }
    }

    public PurgeView get(long id) {
        return logs.findById(id).map(RetentionPurgeService::view).orElseThrow(() -> new ApiException(
                HttpStatus.NOT_FOUND, "RETENTION_PURGE_NOT_FOUND", "Temizlik kaydı bulunamadı."));
    }

    public List<PurgeView> recent() {
        return logs.findTop50ByOrderByIdDesc().stream().map(RetentionPurgeService::view).toList();
    }

    static PurgeView view(DataPurgeLog r) {
        return new PurgeView(r.getId(), r.getTableName(), r.getRangeFrom(), r.getRangeTo(), r.getReceiptId(),
                r.isForced(), r.getStatus().name(), r.getEstRows(), r.getDeletedRows(), r.getOldestAt(),
                r.getNewestAt(), r.getReason(), r.getAdminId(),
                edu.bingol.backend.admin.rbac.PermissionAwareMasking.email(r.getAdminEmail()), r.getError(),
                r.getStartedAt(), r.getUpdatedAt(), r.getFinishedAt(), r.getDeletedRows() > 0);
    }
}
