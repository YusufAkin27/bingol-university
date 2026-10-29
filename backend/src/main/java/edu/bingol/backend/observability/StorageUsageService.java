package edu.bingol.backend.observability;

import edu.bingol.backend.config.StorageCapacityProperties;
import edu.bingol.backend.config.StorageProperties;
import java.io.IOException;
import java.nio.file.FileStore;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Depolama doluluk olcumu: (i) veritabani boyutu + en buyuk 15 tablo, (ii) uygulamanin dizinlerinin (yukleme, yedek,
 * calisma dizini) bulundugu disk bolumleri (statfs, OLCULEN), (iii) veritabani sunucusunun diski.
 *
 * <p>(iii) icin dürüst kaynak: uygulama konteyneri PostgreSQL'in diskini goremeyebilir. {@code app.storage.db-disk-path}
 * (DB ile ayni dosya sisteminde okunabilir dizin) varsa yuzde OLCULUR ({@code MEASURED}); yoksa
 * {@code app.storage.db-disk-capacity-bytes} varsa kullanim = DB + yukleme + yedek + sabit pay toplamindan HESAPLANIR
 * ({@code COMPUTED}); ikisi de yoksa {@code UNKNOWN}. PostgreSQL'e dosya sistemi sorusu SORULMAZ (superuser/pg_monitor
 * gerektirir, guvensiz). Sonuc 30 sn onbelleklenir; dizin boyutu taramasi 10 dk onbelleklenir ve zaman/dosya butcelidir.
 */
@Service
public class StorageUsageService {

    private static final Logger log = LoggerFactory.getLogger(StorageUsageService.class);
    private static final long REPORT_TTL_MS = 30_000;
    private static final long DIR_TTL_MS = 600_000;
    private static final long DIR_BUDGET_MS = 4_000;
    private static final long DIR_MAX_FILES = 2_000_000;

    /** source: MEASURED (statfs), COMPUTED (kapasite ayarindan), UNKNOWN. percent bilinmiyorsa null. */
    public record Disk(String key, List<String> roles, String source, String path, Long totalBytes, Long usedBytes,
                       Long freeBytes, Double percent, IndicatorStatus status) {
    }

    public record TableSize(String name, long totalBytes, Long estimatedRows) {
    }

    public record Database(Long sizeBytes, List<TableSize> topTables) {
    }

    public record Report(Instant generatedAt, IndicatorStatus status, Double worstPercent, String worstKey,
                         Database database, Disk dbServerDisk, List<Disk> appDisks, int warnPercent,
                         int critPercent) {
    }

    private record Cached(long at, Report report) {
    }

    private record DirSize(long at, long bytes, boolean truncated) {
    }

    private final JdbcTemplate jdbc;
    private final StorageProperties storage;
    private final StorageCapacityProperties capacity;
    private final ObservabilityProperties props;
    private final BackupStatusProvider backup;
    private final AtomicReference<Cached> cache = new AtomicReference<>();
    private final Map<Path, DirSize> dirSizes = new ConcurrentHashMap<>();

    public StorageUsageService(JdbcTemplate jdbc, StorageProperties storage, StorageCapacityProperties capacity,
                               ObservabilityProperties props, BackupStatusProvider backup) {
        this.jdbc = jdbc;
        this.storage = storage;
        this.capacity = capacity;
        this.props = props;
        this.backup = backup;
    }

    /** Onbellekli rapor (30 sn). */
    public Report report() {
        long now = System.currentTimeMillis();
        Cached c = cache.get();
        if (c == null || now - c.at() > REPORT_TTL_MS) {
            c = new Cached(now, measure());
            cache.set(c);
        }
        return c.report();
    }

    /** Onbellegi atlayip yeniden olcer (zamanlayici). */
    public Report fresh() {
        Cached c = new Cached(System.currentTimeMillis(), measure());
        cache.set(c);
        return c.report();
    }

    Report measure() {
        Database db = database();
        Path uploads = path(storage.dir(), "./data/uploads");
        Path backups = backup.file().toAbsolutePath().getParent();
        List<Disk> disks = appDisks(uploads, backups);
        Disk dbDisk = dbServerDisk(db, uploads, backups);
        IndicatorStatus worst = IndicatorStatus.UNKNOWN;
        Double worstPct = null;
        String worstKey = null;
        List<Disk> all = new ArrayList<>(disks);
        all.add(dbDisk);
        for (Disk d : all) {
            if (d.percent() != null) {
                worst = IndicatorStatus.worse(worst, d.status());
                if (worstPct == null || d.percent() > worstPct) {
                    worstPct = d.percent();
                    worstKey = d.key();
                }
            }
        }
        return new Report(Instant.now(), worst, worstPct, worstKey, db, dbDisk, disks, props.storageWarnPercent(),
                props.storageCritPercent());
    }

    // ---- veritabani ----

    Database database() {
        Long size = null;
        List<TableSize> top = new ArrayList<>();
        try {
            size = jdbc.queryForObject("SELECT pg_database_size(current_database())", Long.class);
            jdbc.query("SELECT c.relname, pg_total_relation_size(c.oid) AS sz, c.reltuples FROM pg_class c "
                    + "JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = current_schema() "
                    + "AND c.relkind = 'r' ORDER BY sz DESC LIMIT 15", rs -> {
                double rows = rs.getDouble("reltuples");
                top.add(new TableSize(rs.getString("relname"), rs.getLong("sz"), rows < 0 ? null : Math.round(rows)));
            });
        } catch (RuntimeException e) {
            log.debug("Veritabani boyutu okunamadi (PostgreSQL disi olabilir): {}", e.toString());
        }
        return new Database(size, top);
    }

    // ---- uygulama diskleri (statfs) ----

    private List<Disk> appDisks(Path uploads, Path backups) {
        Map<Object, List<String>> roles = new LinkedHashMap<>();
        Map<Object, Path> sample = new LinkedHashMap<>();
        Map<Object, FileStore> stores = new LinkedHashMap<>();
        addStore("uploads", uploads, roles, sample, stores);
        addStore("backups", backups, roles, sample, stores);
        addStore("app", Path.of(".").toAbsolutePath().normalize(), roles, sample, stores);
        List<Disk> out = new ArrayList<>();
        for (Map.Entry<Object, FileStore> e : stores.entrySet()) {
            out.add(statfs("app:" + String.join("+", roles.get(e.getKey())), roles.get(e.getKey()), "MEASURED",
                    sample.get(e.getKey()), e.getValue()));
        }
        return out;
    }

    private void addStore(String role, Path p, Map<Object, List<String>> roles, Map<Object, Path> sample,
                          Map<Object, FileStore> stores) {
        try {
            Path existing = nearestExisting(p);
            if (existing == null) {
                return;
            }
            FileStore fs = Files.getFileStore(existing);
            Object id = fs.name() + "|" + fs.type() + "|" + fs.getTotalSpace();
            roles.computeIfAbsent(id, k -> new ArrayList<>()).add(role);
            sample.putIfAbsent(id, existing);
            stores.putIfAbsent(id, fs);
        } catch (IOException | RuntimeException e) {
            log.debug("Disk bolumu okunamadi ({}): {}", role, e.toString());
        }
    }

    private Disk statfs(String key, List<String> roles, String source, Path path, FileStore fs) {
        try {
            long total = fs.getTotalSpace();
            long free = fs.getUnallocatedSpace();
            long avail = fs.getUsableSpace();
            if (total <= 0) {
                return unknown(key, roles, path);
            }
            long used = Math.max(0, total - free);
            // df ile ayni: kullanim / (kullanim + kullanilabilir) (kok icin ayrilmis bloklar dahil edilmez)
            double pct = used + avail <= 0 ? 0 : used * 100.0 / (used + avail);
            return disk(key, roles, source, path, total, used, avail, pct);
        } catch (IOException | RuntimeException e) {
            return unknown(key, roles, path);
        }
    }

    // ---- veritabani sunucusu diski ----

    private Disk dbServerDisk(Database db, Path uploads, Path backups) {
        String dbPath = capacity.dbDiskPath();
        if (dbPath != null && !dbPath.isBlank()) {
            Path p = Path.of(dbPath.trim());
            if (Files.exists(p)) {
                try {
                    return statfs("db-server", List.of("db"), "MEASURED", p, Files.getFileStore(p));
                } catch (IOException | RuntimeException e) {
                    log.debug("db-disk-path okunamadi: {}", e.toString());
                }
            }
        }
        long cap = capacity.dbDiskCapacityBytes();
        if (cap > 0 && db.sizeBytes() != null) {
            long used = db.sizeBytes() + dirSize(uploads) + dirSize(backups) + Math.max(0, capacity.reservedBytes());
            double pct = used * 100.0 / cap;
            return disk("db-server", List.of("db"), "COMPUTED", null, cap, used, Math.max(0, cap - used), pct);
        }
        return new Disk("db-server", List.of("db"), "UNKNOWN", null, null, null, null, null, IndicatorStatus.UNKNOWN);
    }

    private Disk disk(String key, List<String> roles, String source, Path path, long total, long used, long free,
                      double pct) {
        double rounded = Math.round(pct * 10) / 10.0;
        IndicatorStatus st = Indicator.byThreshold(rounded, props.storageWarnPercent(), props.storageCritPercent());
        return new Disk(key, roles, source, path == null ? null : path.toString(), total, used, free, rounded, st);
    }

    private Disk unknown(String key, List<String> roles, Path path) {
        return new Disk(key, roles, "UNKNOWN", path == null ? null : path.toString(), null, null, null, null,
                IndicatorStatus.UNKNOWN);
    }

    // ---- yardimcilar ----

    private static Path path(String configured, String fallback) {
        return Path.of(configured == null || configured.isBlank() ? fallback : configured).toAbsolutePath().normalize();
    }

    static Path nearestExisting(Path p) {
        Path cur = p;
        while (cur != null && !Files.exists(cur)) {
            cur = cur.getParent();
        }
        return cur;
    }

    /** Dizin toplam boyutu (10 dk onbellek, zaman/dosya butceli; dizin yoksa 0). */
    long dirSize(Path dir) {
        if (dir == null || !Files.isDirectory(dir)) {
            return 0;
        }
        long now = System.currentTimeMillis();
        DirSize c = dirSizes.get(dir);
        if (c != null && now - c.at() < DIR_TTL_MS) {
            return c.bytes();
        }
        long[] acc = {0, 0};
        long deadline = now + DIR_BUDGET_MS;
        boolean[] truncated = {false};
        try {
            Files.walkFileTree(dir, new SimpleFileVisitor<>() {
                @Override
                public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) {
                    acc[0] += attrs.size();
                    acc[1]++;
                    if (acc[1] > DIR_MAX_FILES || System.currentTimeMillis() > deadline) {
                        truncated[0] = true;
                        return FileVisitResult.TERMINATE;
                    }
                    return FileVisitResult.CONTINUE;
                }

                @Override
                public FileVisitResult visitFileFailed(Path file, IOException exc) {
                    return FileVisitResult.CONTINUE;
                }
            });
        } catch (IOException | RuntimeException e) {
            log.debug("Dizin boyutu okunamadi: {}", e.toString());
        }
        dirSizes.put(dir, new DirSize(now, acc[0], truncated[0]));
        return acc[0];
    }
}
