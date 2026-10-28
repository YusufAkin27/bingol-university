package edu.bingol.backend.observability;

import edu.bingol.backend.config.StorageProperties;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Son basarili yedek zamanini DOSYADAN okur; dosyayi yedek ajani yazar (bu sinif yalniz okur, hicbir sey calistirmaz).
 *
 * <p>Konum: {@code app.observability.backup-status-file} (env {@code BACKUP_STATUS_FILE}); bos ise
 * {@code ${STORAGE_DIR}/../backups/last-success.json}. Beklenen icerik (atomik yazilmali):
 * <pre>{"lastSuccessAt":"2026-10-28T09:00:00Z"}</pre>
 * Kabul edilen alan adlari: {@code lastSuccessAt}, {@code timestamp}, {@code epochSeconds}, {@code time}; deger ISO-8601
 * metin ya da unix saniye/milisaniye sayisi olabilir. Duz metin (yalniz sayi) de kabul edilir. Dosya yok/okunamaz/ayrisamaz
 * ise sonuc "bilinmiyor" (Optional.empty) olur: UNKNOWN uyari tetiklemez ama panelde gorunur.
 */
@Component
public class BackupStatusProvider {

    private static final long MAX_BYTES = 64 * 1024;
    private static final Pattern FIELD = Pattern.compile(
            "\"(?:lastSuccessAt|timestamp|epochSeconds|time)\"\\s*:\\s*(?:\"([^\"]+)\"|([0-9]+(?:\\.[0-9]+)?))");
    private static final Pattern PLAIN_NUMBER = Pattern.compile("^\\s*([0-9]+(?:\\.[0-9]+)?)\\s*$");

    private final Path file;

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
            if (!Files.isRegularFile(file) || Files.size(file) > MAX_BYTES) {
                return Optional.empty();
            }
            return parse(Files.readString(file, StandardCharsets.UTF_8));
        } catch (IOException | RuntimeException e) {
            return Optional.empty();
        }
    }

    static Optional<Instant> parse(String content) {
        if (content == null) {
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
