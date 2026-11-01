package edu.bingol.backend.observability;

import edu.bingol.backend.config.StorageProperties;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/**
 * Yedek durumunu DOSYADAN okur; dosyayi yedek ajani yazar (bu sinif yalniz okur, hicbir sey calistirmaz, aga cikmaz).
 *
 * <p>Konum: {@code app.observability.backup-status-file} (env {@code BACKUP_STATUS_FILE}); bos ise
 * {@code ${STORAGE_DIR}/../backups/last-success.json}. Beklenen icerik (atomik yazilmali):
 * <pre>{"lastSuccessAt":"2026-10-28T09:00:00Z"}</pre>
 * Kabul edilen alan adlari: {@code lastSuccessAt}, {@code timestamp}, {@code epochSeconds}, {@code time}; deger ISO-8601
 * metin ya da unix saniye/milisaniye sayisi olabilir. Duz metin (yalniz sayi) de kabul edilir. Dosya yok/okunamaz/ayrisamaz
 * ise sonuc "bilinmiyor" (Optional.empty) olur: UNKNOWN uyari tetiklemez ama panelde gorunur.
 *
 * <p>Yeni (GDRIVE-BACKUP) isteğe bagli alanlar: {@code local}, {@code remote}, {@code schedule}, {@code retention}
 * ({@link #report()}). Eski biçim (bu alanlar yok) ayni sekilde calisir: {@code remote.configured=false}, digerleri null.
 * Ayni dizindeki {@code last-failure.json} varsa {@code lastStatus=FAILED} turetilir.
 */
@Component
public class BackupStatusProvider {

    private static final long MAX_BYTES = 64 * 1024;
    private static final int MAX_ERROR = 200;
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final List<String> TIME_KEYS = List.of("lastSuccessAt", "timestamp", "epochSeconds", "time");
    private static final Pattern FIELD = Pattern.compile(
            "\"(?:lastSuccessAt|timestamp|epochSeconds|time)\"\\s*:\\s*(?:\"([^\"]+)\"|([0-9]+(?:\\.[0-9]+)?))");
    private static final Pattern PLAIN_NUMBER = Pattern.compile("^\\s*([0-9]+(?:\\.[0-9]+)?)\\s*$");
    /** Yalniz rclone uzak adi: yol/belirtec bicimleri (":" "/" bosluk) kabul edilmez. */
    private static final Pattern REMOTE_NAME = Pattern.compile("^[A-Za-z0-9_.-]{1,64}$");
    private static final DateTimeFormatter OFFSET_NO_COLON = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssZ");

    private final Path file;

    @Autowired
    public BackupStatusProvider(ObservabilityProperties props, StorageProperties storage) {
        this.file = resolvePath(props.backupStatusFile(), storage == null ? null : storage.dir());
    }

    /** Test icin: dogrudan dosya yolu. */
    BackupStatusProvider(Path file) {
        this.file = file;
    }

    static Path resolvePath(String configured, String storageDir) {
        if (configured != null && !configured.isBlank()) {
            return Path.of(configured.trim());
        }
        Path base = Path.of(storageDir == null || storageDir.isBlank() ? "./data/uploads" : storageDir)
                .toAbsolutePath().normalize();
        Path parent = base.getParent() == null ? base : base.getParent();
        return parent.resolve("backups").resolve("last-success.json");
    }

    public Path file() {
        return file;
    }

    /** Son basarili yedek zamani; dosya yok/okunamiyor/ayrisamiyorsa bos. */
    public Optional<Instant> lastSuccess() {
        try {
            String content = read(file);
            return content == null ? Optional.empty() : parse(content);
        } catch (IOException | RuntimeException e) {
            return Optional.empty();
        }
    }

    /**
     * Yonetim paneli icin yedek raporu. Hicbir hata disari sizmaz: dosya yok/bozuksa {@link BackupReport#unknown()}.
     * Beklenmeyen/uygunsuz alanlar (ornegin yol iceren uzak adi) null'a duser.
     */
    public BackupReport report() {
        try {
            String content = read(file);
            if (content == null) {
                return BackupReport.unknown();
            }
            Map<String, Object> root = readObject(content);
            Instant last = parse(content).orElse(null);
            Map<String, Object> local = obj(root, "local");
            Map<String, Object> remote = obj(root, "remote");
            Map<String, Object> schedule = obj(root, "schedule");
            Map<String, Object> retention = obj(root, "retention");

            BackupReport.Local l = new BackupReport.Local(num(local, "count"), num(local, "bytes"), instant(local, "oldestAt"));
            boolean configured = remote != null && Boolean.TRUE.equals(remote.get("configured"));
            BackupReport.Remote r = !configured
                    ? new BackupReport.Remote(false, null, null, null, null, null, null, null)
                    : new BackupReport.Remote(true, kind(remote), name(remote), instant(remote, "lastSuccessAt"),
                            instant(remote, "lastVerifiedAt"), shortText(remote, "lastError"),
                            num(remote, "bytes"), num(remote, "count"));
            BackupReport.Schedule s = new BackupReport.Schedule(shortText(schedule, "cron"), shortText(schedule, "verifyCron"),
                    shortText(schedule, "remoteCron"));
            BackupReport.Retention t = new BackupReport.Retention(integer(retention, "localDaily"),
                    integer(retention, "localWeekly"), integer(retention, "localMonthly"),
                    integer(retention, "remoteDaily"), integer(retention, "remoteWeekly"), integer(retention, "remoteMonthly"));
            return new BackupReport(l, r, last, lastStatus(last), s, t);
        } catch (IOException | RuntimeException e) {
            return BackupReport.unknown();
        }
    }

    // ---- dahili ----

    private static String read(Path f) throws IOException {
        if (!Files.isRegularFile(f) || Files.size(f) > MAX_BYTES) {
            return null;
        }
        return Files.readString(f, StandardCharsets.UTF_8);
    }

    /** OK: son basarili yedek var ve sonrasinda basarisizlik kaydi yok; FAILED: basarisizlik kaydi daha yeni; bilinmiyorsa null. */
    private String lastStatus(Instant lastSuccess) {
        Path failure = file.toAbsolutePath().getParent() == null ? null
                : file.toAbsolutePath().getParent().resolve("last-failure.json");
        Instant failedAt = null;
        boolean failureFile = false;
        try {
            String content = failure == null ? null : read(failure);
            if (content != null) {
                failureFile = true;
                Object t = readObject(content).get("time");
                failedAt = t == null ? null : time(String.valueOf(t));
            }
        } catch (IOException | RuntimeException e) {
            failureFile = failure != null && Files.exists(failure);
        }
        if (failureFile && (lastSuccess == null || failedAt == null || failedAt.isAfter(lastSuccess))) {
            return "FAILED";
        }
        return lastSuccess == null ? null : "OK";
    }

    private static Map<String, Object> readObject(String content) {
        try {
            Map<String, Object> m = JSON.readValue(content, new TypeReference<Map<String, Object>>() { });
            return m == null ? Map.of() : m;
        } catch (RuntimeException e) {
            return Map.of();
        }
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> obj(Map<String, Object> root, String key) {
        Object v = root == null ? null : root.get(key);
        return v instanceof Map<?, ?> m ? (Map<String, Object>) m : null;
    }

    private static Long num(Map<String, Object> m, String key) {
        Object v = m == null ? null : m.get(key);
        return v instanceof Number n && n.longValue() >= 0 ? n.longValue() : null;
    }

    private static Integer integer(Map<String, Object> m, String key) {
        Long v = num(m, key);
        return v == null || v > Integer.MAX_VALUE ? null : v.intValue();
    }

    private static Instant instant(Map<String, Object> m, String key) {
        Object v = m == null ? null : m.get(key);
        return v == null ? null : time(String.valueOf(v));
    }

    private static Instant time(String text) {
        Optional<Instant> i = fromText(text);
        if (i.isPresent()) {
            return i.get();
        }
        try {
            return OffsetDateTime.parse(text.trim(), OFFSET_NO_COLON).toInstant();
        } catch (RuntimeException e) {
            return null;
        }
    }

    /** Kisa, tek satir metin (panelde gosterilir); kontrol karakterleri atilir. */
    private static String shortText(Map<String, Object> m, String key) {
        Object v = m == null ? null : m.get(key);
        if (!(v instanceof String s) || s.isBlank()) {
            return null;
        }
        String clean = s.replaceAll("\\p{Cntrl}", " ").trim();
        return clean.length() > MAX_ERROR ? clean.substring(0, MAX_ERROR) : clean;
    }

    private static String kind(Map<String, Object> remote) {
        Object v = remote.get("kind");
        return "drive".equals(v) ? "drive" : "other";
    }

    private static String name(Map<String, Object> remote) {
        Object v = remote.get("name");
        return v instanceof String s && REMOTE_NAME.matcher(s).matches() ? s : null;
    }

    static Optional<Instant> parse(String content) {
        if (content == null) {
            return Optional.empty();
        }
        Map<String, Object> root = readObject(content);
        if (!root.isEmpty()) {
            // yalniz ust duzey anahtarlar: remote.lastSuccessAt gibi ic ice alanlar yedek zamani sayilmaz
            for (String key : TIME_KEYS) {
                Object v = root.get(key);
                if (v instanceof Number n) {
                    return fromNumber(n.toString());
                }
                if (v instanceof String s) {
                    return fromText(s);
                }
            }
            return Optional.empty();
        }
        Matcher m = FIELD.matcher(content);
        if (m.find()) {
            return m.group(1) != null ? fromText(m.group(1)) : fromNumber(m.group(2));
        }
        Matcher p = PLAIN_NUMBER.matcher(content);
        return p.find() ? fromNumber(p.group(1)) : Optional.empty();
    }

    private static Optional<Instant> fromText(String text) {
        try {
            return Optional.of(Instant.parse(text.trim()));
        } catch (RuntimeException e) {
            return PLAIN_NUMBER.matcher(text).matches() ? fromNumber(text.trim()) : Optional.empty();
        }
    }

    private static Optional<Instant> fromNumber(String text) {
        try {
            double v = Double.parseDouble(text);
            if (v <= 0) {
                return Optional.empty();
            }
            // 1e11 ustu milisaniye sayilir (saniye cinsinden 1e11 yil 5138'dir)
            return Optional.of(v > 1e11 ? Instant.ofEpochMilli((long) v) : Instant.ofEpochSecond((long) v));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }
}
