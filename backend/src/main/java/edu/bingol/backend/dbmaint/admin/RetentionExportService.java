package edu.bingol.backend.dbmaint.admin;

import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.dbmaint.admin.RetentionTables.Col;
import edu.bingol.backend.dbmaint.admin.RetentionTables.Spec;
import java.io.BufferedWriter;
import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Semaphore;
import java.util.zip.GZIPOutputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Akisli (streaming) gzip'li CSV disa aktarma. Bellekte tum veri tutulmaz: keyset sayfalama ({@code id > :last
 * ORDER BY id LIMIT n}, kucuk sorgular) ile sayfa sayfa yazilir. Cikti: UTF-8 BOM'suz, hucreler CSV enjeksiyonuna
 * karsi kacirilmis ({@link Csv#cell}), kisisel kolonlar izin yoksa maskeli. Baslamadan once RUNNING makbuzu yazilir;
 * bitince satir sayisi + indirilen (gzip) baytlarin SHA-256'si ile TAMAMLANIR. Ust sinira (satir) ulasirsa PARTIAL olur
 * ve silmeyi mesrulastirmaz.
 */
@Service
public class RetentionExportService {

    private static final Logger log = LoggerFactory.getLogger(RetentionExportService.class);

    /** Baslamis disa aktarma: makbuz + dogrulanmis girdi. */
    public record Started(DataExportReceipt receipt, Spec spec, RetentionService.Range range, Semaphore slot) {
    }

    private final NamedParameterJdbcTemplate jdbc;
    private final DataExportReceiptRepository receipts;
    private final Semaphore slots;
    private final int pageSize;
    private final long maxRows;

    public RetentionExportService(NamedParameterJdbcTemplate jdbc, DataExportReceiptRepository receipts,
                                  @Value("${app.retention.export-page-size:2000}") int pageSize,
                                  @Value("${app.retention.export-max-rows:5000000}") long maxRows,
                                  @Value("${app.retention.export-concurrency:2}") int concurrency) {
        this.jdbc = jdbc;
        this.receipts = receipts;
        this.pageSize = Math.max(100, Math.min(pageSize, 10_000));
        this.maxRows = Math.max(1000, maxRows);
        this.slots = new Semaphore(Math.max(1, concurrency));
    }

    /** Es zamanli disa aktarma yuvasi alir (yoksa 429) ve RUNNING makbuzunu yazar. */
    public Started begin(Spec spec, RetentionService.Range range, Long adminId, String adminEmail, String reason,
                         String requestId) {
        if (!slots.tryAcquire()) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RETENTION_EXPORT_BUSY",
                    "Başka dışa aktarmalar sürüyor; birazdan tekrar deneyin.");
        }
        try {
            DataExportReceipt r = new DataExportReceipt();
            r.setTableName(spec.name());
            r.setRangeFrom(range.from());
            r.setRangeTo(range.toExclusive());
            r.setAdminId(adminId);
            r.setAdminEmail(adminEmail);
            r.setReason(reason == null ? null : reason.length() > 300 ? reason.substring(0, 300) : reason);
            r.setRequestId(requestId);
            return new Started(receipts.save(r), spec, range, slots);
        } catch (RuntimeException e) {
            slots.release();
            throw e;
        }
    }

    /**
     * Veriyi {@code raw}'a yazar ve makbuzu bitirir. {@code raw} KAPATILMAZ (kapsayici kapatir): makbuz, son bayt
     * istemciye tamamlanmadan once guncellenir. Hatada makbuz FAILED olur ve istisna yeniden firlatilir.
     */
    public DataExportReceipt stream(Started st, OutputStream raw) throws IOException {
        Spec spec = st.spec();
        DataExportReceipt rec = st.receipt();
        MessageDigest md = sha256();
        Counting dig = new Counting(raw, md);
        long rows = 0;
        boolean partial = false;
        try {
            if (!spec.columns().get(0).name().equals(spec.keyColumn())) {
                throw new IllegalStateException("anahtar kolonu ilk kolon olmali: " + spec.name());
            }
            GZIPOutputStream gz = new GZIPOutputStream(dig, 64 * 1024);
            Writer w = new BufferedWriter(new OutputStreamWriter(gz, StandardCharsets.UTF_8), 64 * 1024);
            w.write(Csv.row(spec.columns().stream().map(Col::name).toList()));
            boolean pii = PermissionAwareMasking.canSeePii();
            String sql = "SELECT " + spec.columnList() + " FROM " + spec.name() + " WHERE " + spec.rangeWhere()
                    + " AND " + spec.keyColumn() + " > :last ORDER BY " + spec.keyColumn() + " LIMIT :n";
            Map<String, Object> p = new HashMap<>(st.range().params());
            p.put("n", pageSize);
            long last = Long.MIN_VALUE;
            while (true) {
                p.put("last", last);
                List<List<Object>> page = new ArrayList<>(pageSize);
                jdbc.query(sql, p, rs -> {
                    int n = spec.columns().size();
                    List<Object> row = new ArrayList<>(n);
                    for (int i = 1; i <= n; i++) {
                        row.add(rs.getObject(i));
                    }
                    page.add(row);
                });
                for (List<Object> row : page) {
                    w.write(Csv.row(cells(spec, row, pii)));
                }
                rows += page.size();
                if (page.size() < pageSize) {
                    break;
                }
                last = ((Number) page.get(page.size() - 1).get(0)).longValue();
                if (rows >= maxRows) {
                    partial = true;
                    break;
                }
            }
            w.flush();
            gz.finish();
            rec.setRowCount(rows);
            rec.setByteCount(dig.count());
            rec.setSha256(HexFormat.of().formatHex(md.digest()));
            rec.setStatus(partial ? DataExportReceipt.Status.PARTIAL : DataExportReceipt.Status.COMPLETED);
            rec.setFinishedAt(Instant.now());
            return receipts.save(rec);
        } catch (IOException | RuntimeException e) {
            log.warn("Disa aktarma basarisiz ({} makbuz {}): {}", spec.name(), rec.getId(), e.toString());
            rec.setRowCount(rows);
            rec.setByteCount(dig.count());
            rec.setStatus(DataExportReceipt.Status.FAILED);
            rec.setFinishedAt(Instant.now());
            try {
                receipts.save(rec);
            } catch (RuntimeException ignore) {
                // makbuz yazilamadi: RUNNING kalir, silmeyi zaten mesrulastirmaz
            }
            throw e;
        } finally {
            st.slot().release();
        }
    }

    /** Hata yolunda (akis hic baslamadan) yuvayi birakir ve makbuzu FAILED yapar. */
    public void abort(Started st) {
        try {
            st.receipt().setStatus(DataExportReceipt.Status.FAILED);
            st.receipt().setFinishedAt(Instant.now());
            receipts.save(st.receipt());
        } finally {
            st.slot().release();
        }
    }

    /** Saf: satir degerlerini CSV hucrelerine cevirir (maskeleme + zaman bicimi). */
    static List<Object> cells(Spec spec, List<Object> row, boolean pii) {
        List<Object> out = new ArrayList<>(row.size());
        for (int i = 0; i < row.size(); i++) {
            Object v = row.get(i);
            Col c = spec.columns().get(i);
            if (v instanceof Timestamp ts) {
                v = ts.toInstant().toString();
            } else if (v instanceof java.time.OffsetDateTime odt) {
                v = odt.toInstant().toString();
            } else if (v != null) {
                v = v.toString();
            }
            if (v != null && !pii) {
                v = switch (c.kind()) {
                    case EMAIL -> PermissionAwareMasking.maskEmail((String) v);
                    case OPAQUE -> "***";
                    case PLAIN -> v;
                };
            }
            out.add(v);
        }
        return out;
    }

    private static MessageDigest sha256() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    /** Yazilan baytlari sayar ve ozete katar; alttaki akisi kapatmaz. */
    private static final class Counting extends FilterOutputStream {
        private final MessageDigest md;
        private long count;

        Counting(OutputStream out, MessageDigest md) {
            super(out);
            this.md = md;
        }

        @Override
        public void write(int b) throws IOException {
            out.write(b);
            md.update((byte) b);
            count++;
        }

        @Override
        public void write(byte[] b, int off, int len) throws IOException {
            out.write(b, off, len);
            md.update(b, off, len);
            count += len;
        }

        @Override
        public void close() throws IOException {
            flush();
        }

        long count() {
            return count;
        }
    }
}
