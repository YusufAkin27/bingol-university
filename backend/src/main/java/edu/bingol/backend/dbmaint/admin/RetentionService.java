package edu.bingol.backend.dbmaint.admin;

import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.PurgePreview;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.ReceiptView;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.TableInfo;
import edu.bingol.backend.dbmaint.admin.RetentionTables.Spec;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Saklama ve temizlik: tablo envanteri (tahmini satir/boyut/en eski kayit), aralik dogrulama (asgari saklama suresi),
 * silme onizlemesi ve makbuz kapsami. Tam COUNT yoktur: onizleme sayimi ust sinirlidir ({@code LIMIT}); satir sayisi
 * {@code pg_class.reltuples} tahminidir. PostgreSQL'e ozel katalog sorgulari H2'de calismaz (bos/null doner).
 */
@Service
public class RetentionService {

    private static final Logger log = LoggerFactory.getLogger(RetentionService.class);
    static final ZoneId ISTANBUL = ZoneId.of("Europe/Istanbul");
    /** "Bastan" = aralik baslangici verilmezse. */
    static final LocalDate EPOCH = LocalDate.of(1970, 1, 1);

    /** Dogrulanmis aralik: from dahil, toExclusive haric. */
    public record Range(LocalDate from, LocalDate toExclusive) {
        Map<String, Object> params() {
            return Map.of("from", from.atStartOfDay(ISTANBUL).toOffsetDateTime(),
                    "to", toExclusive.atStartOfDay(ISTANBUL).toOffsetDateTime());
        }
    }

    private record Stats(Long rows, Long bytes) {
    }

    private final NamedParameterJdbcTemplate jdbc;
    private final DataExportReceiptRepository receipts;
    private final Clock clock;
    private final long previewCap;

    public RetentionService(NamedParameterJdbcTemplate jdbc, DataExportReceiptRepository receipts, Clock clock,
                            @Value("${app.retention.preview-count-cap:1000000}") long previewCap) {
        this.jdbc = jdbc;
        this.receipts = receipts;
        this.clock = clock;
        this.previewCap = Math.max(1000, previewCap);
    }

    public Spec requireSpec(String table) {
        return RetentionTables.find(table).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "RETENTION_TABLE_UNKNOWN", "Bu tablo saklama listesinde yok."));
    }

    public LocalDate today() {
        return LocalDate.now(clock.withZone(ISTANBUL));
    }

    /** Silinebilecek/aktarilabilecek en gec bitis (haric): bugun - asgari saklama gunu. */
    public LocalDate maxTo(Spec spec) {
        return today().minusDays(spec.minDays());
    }

    /** from bos = baslangic yok; to ZORUNLU ve asgari saklama suresinden yeni olamaz. */
    public Range resolveRange(Spec spec, LocalDate from, LocalDate to) {
        if (to == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RETENTION_RANGE_INVALID", "Tarih aralığı geçersiz.");
        }
        LocalDate f = from == null ? EPOCH : from;
        if (!f.isBefore(to) || f.isBefore(EPOCH)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RETENTION_RANGE_INVALID", "Tarih aralığı geçersiz.");
        }
        LocalDate max = maxTo(spec);
        if (to.isAfter(max)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "RETENTION_RANGE_TOO_RECENT",
                    "Bitiş tarihi asgari saklama süresinden yeni olamaz.", String.valueOf(spec.minDays()),
                    max.toString());
        }
        return new Range(f, to);
    }

    // ---- envanter ----

    public List<TableInfo> tables() {
        Map<String, Stats> stats = stats(RetentionTables.all().stream().map(Spec::name).toList());
        List<TableInfo> out = new ArrayList<>();
        for (Spec s : RetentionTables.all()) {
            Stats st = stats.get(s.name());
            out.add(new TableInfo(s.name(), s.label(), s.description(), st == null ? null : st.rows(),
                    st == null ? null : st.bytes(), oldest(s), s.minDays(), maxTo(s), s.deletable(),
                    s.notDeletableReason(), s.personalData()));
        }
        return out;
    }

    private Map<String, Stats> stats(List<String> names) {
        Map<String, Stats> out = new HashMap<>();
        try {
            jdbc.query("SELECT c.relname, c.reltuples, pg_total_relation_size(c.oid) AS sz FROM pg_class c "
                            + "JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = current_schema() "
                            + "AND c.relkind IN ('r', 'p') AND c.relname IN (:names)",
                    Map.of("names", names), rs -> {
                        double rows = rs.getDouble("reltuples");
                        out.put(rs.getString("relname"), new Stats(rows < 0 ? null : Math.round(rows),
                                rs.getLong("sz")));
                    });
        } catch (RuntimeException e) {
            log.debug("Tablo istatistigi okunamadi (PostgreSQL disi olabilir): {}", e.toString());
        }
        return out;
    }

    /** En eski kayit zamani (anahtar sirasina gore ilk satir; tam tarama yapmaz). Okunamazsa null. */
    Instant oldest(Spec s) {
        try {
            String where = s.extraWhere() == null || s.extraWhere().isBlank() ? "" : " WHERE " + s.extraWhere();
            List<Instant> r = jdbc.getJdbcTemplate().query("SELECT " + s.timeColumn() + " FROM " + s.name() + where
                            + " ORDER BY " + s.keyColumn() + " ASC LIMIT 1",
                    (rs, i) -> rs.getObject(1, OffsetDateTime.class).toInstant());
            return r.isEmpty() ? null : r.get(0);
        } catch (RuntimeException e) {
            log.debug("En eski kayit okunamadi ({}): {}", s.name(), e.toString());
            return null;
        }
    }

    // ---- onizleme ----

    /** Aralikta ust sinirli sayim: {sayi, sinirlandi(1/0)}. Sayi en cok previewCap olur. */
    long[] countCapped(Spec s, Range r) {
        Map<String, Object> p = new HashMap<>(r.params());
        p.put("cap", previewCap + 1);
        Long n = jdbc.queryForObject("SELECT count(*) FROM (SELECT 1 FROM " + s.name() + " WHERE " + s.rangeWhere()
                + " LIMIT :cap) x", p, Long.class);
        long c = n == null ? 0 : n;
        return new long[] {Math.min(c, previewCap), c > previewCap ? 1 : 0};
    }

    public PurgePreview preview(Spec s, Range r) {
        long[] c = countCapped(s, r);
        Stats st = stats(List.of(s.name())).get(s.name());
        Long estBytes = null;
        if (st != null && st.rows() != null && st.rows() > 0 && st.bytes() != null) {
            estBytes = Math.round((double) st.bytes() / st.rows() * c[0]);
        }
        List<String> blockers = new ArrayList<>();
        if (!s.deletable()) {
            blockers.add("NOT_DELETABLE");
        }
        DataExportReceipt rec = receipts.covering(s.name(), r.from(), r.toExclusive(), PageRequest.of(0, 1))
                .stream().findFirst().orElse(null);
        boolean stale = rec != null && c[0] + c[1] > rec.getRowCount();
        if (rec == null) {
            blockers.add("NO_RECEIPT");
        } else if (stale) {
            blockers.add("RECEIPT_STALE");
        }
        if (c[0] == 0) {
            blockers.add("NOTHING_TO_DELETE");
        }
        boolean can = s.deletable() && rec != null && !stale && c[0] > 0;
        return new PurgePreview(s.name(), r.from(), r.toExclusive(), c[0], c[1] == 1, estBytes, s.deletable(),
                s.notDeletableReason(), maxTo(s), s.minDays(), rec == null ? null : view(rec), stale, can, blockers);
    }

    // ---- makbuz ----

    /** Silmeyi mesrulastiran makbuz: verilen kimlik araligi kapsamali, yoksa en yeni kapsayan (yoksa null). */
    public DataExportReceipt coveringReceipt(Spec s, Range r, Long receiptId) {
        if (receiptId != null) {
            DataExportReceipt rec = receipts.findById(receiptId).orElseThrow(() -> new ApiException(
                    HttpStatus.NOT_FOUND, "RETENTION_RECEIPT_NOT_FOUND", "Makbuz bulunamadı."));
            if (!rec.getTableName().equals(s.name()) || rec.getStatus() != DataExportReceipt.Status.COMPLETED
                    || rec.getRangeFrom().isAfter(r.from()) || rec.getRangeTo().isBefore(r.toExclusive())) {
                throw new ApiException(HttpStatus.CONFLICT, "RETENTION_RECEIPT_INVALID",
                        "Makbuz bu tablo ve tarih aralığını kapsamıyor.");
            }
            return rec;
        }
        return receipts.covering(s.name(), r.from(), r.toExclusive(), PageRequest.of(0, 1)).stream().findFirst()
                .orElse(null);
    }

    public static ReceiptView view(DataExportReceipt r) {
        return new ReceiptView(r.getId(), r.getTableName(), r.getRangeFrom(), r.getRangeTo(), r.getFormat(),
                r.getStatus().name(), r.getRowCount(), r.getByteCount(), r.getSha256(), r.getAdminId(),
                PermissionAwareMasking.email(r.getAdminEmail()), r.getReason(), r.getCreatedAt(), r.getFinishedAt());
    }
}
