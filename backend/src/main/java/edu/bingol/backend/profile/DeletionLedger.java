package edu.bingol.backend.profile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Silme defteri (T-064, A8-17): hesap silinince kullanici kimligi YEDEK DISI bir dosyaya eklenir
 * ({@code app.privacy.deletion-ledger-file}; bos = kapali). Yedekten geri yuklenince silinmis hesaplar canlanir;
 * {@link DeletionLedgerReapplier} bu deftere bakip yeniden anonimlestirir.
 *
 * <p>Satir bicimi: {@code <userId>\t<silinmeAni ISO>\t<hesapOlusturmaSaniyesi>}. Yalniz sayisal kimlik ve zaman
 * (e-posta/ad YOK; kimlik anonimlesmis hesaba bagli). Olusturma saniyesi, geri yukleme sonrasi AYNI kimligi alan
 * baska bir hesabin yanlislikla anonimlestirilmesini onler. Dosya VERITABANI/UPLOADS YEDEGININ DISINDA bir
 * hacimde olmali ve ayri kopyalanmalidir (docs/BACKUP_RESTORE.md). Hata hesap silmeyi engellemez.
 */
@Component
public class DeletionLedger {

    private static final Logger log = LoggerFactory.getLogger(DeletionLedger.class);

    /** Defter satiri: kullanici kimligi, hesabin olusturulma saniyesi (yoksa 0). */
    public record Entry(long userId, long createdEpochSec) {}

    private final Path file;
    private JdbcTemplate jdbc;

    public DeletionLedger(@Value("${app.privacy.deletion-ledger-file:}") String path) {
        this.file = path == null || path.isBlank() ? null : Path.of(path.trim());
    }

    @Autowired(required = false)
    void setJdbc(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public boolean enabled() {
        return file != null;
    }

    /** Kimligi deftere ekler (idempotent degil; okuma tarafi tekilleştirir). Hic exception sizdirmaz. */
    public void record(Long userId) {
        if (file == null || userId == null) {
            return;
        }
        try {
            long created = 0;
            if (jdbc != null) {
                try {
                    java.sql.Timestamp ts = jdbc.queryForObject("SELECT created_at FROM app_user WHERE id = ?",
                            java.sql.Timestamp.class, userId);
                    created = ts == null ? 0 : ts.toInstant().getEpochSecond();
                } catch (RuntimeException e) {
                    log.debug("Silme defteri: olusturma zamani okunamadi ({}): {}", userId, e.toString());
                }
            }
            if (file.getParent() != null) {
                Files.createDirectories(file.getParent());
            }
            String line = userId + "\t" + Instant.now() + "\t" + created + "\n";
            Files.writeString(file, line, StandardCharsets.UTF_8, StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException | RuntimeException e) {
            log.warn("Silme defterine yazilamadi (kullanici {}): {}", userId, e.toString());
        }
    }

    /** Defterdeki tekil kayitlar (kimlik -> olusturma saniyesi). Dosya yoksa/okunamazsa bos. */
    public Map<Long, Entry> read() {
        Map<Long, Entry> out = new LinkedHashMap<>();
        if (file == null || !Files.isRegularFile(file)) {
            return out;
        }
        try {
            for (String line : Files.readAllLines(file, StandardCharsets.UTF_8)) {
                String[] p = line.split("\t");
                if (p.length < 1 || p[0].isBlank()) {
                    continue;
                }
                try {
                    long id = Long.parseLong(p[0].trim());
                    long created = p.length >= 3 ? Long.parseLong(p[2].trim()) : 0;
                    out.put(id, new Entry(id, created));
                } catch (NumberFormatException ignored) {
                    // bozuk satir atlanir
                }
            }
        } catch (IOException e) {
            log.warn("Silme defteri okunamadi: {}", e.toString());
        }
        return out;
    }
}
