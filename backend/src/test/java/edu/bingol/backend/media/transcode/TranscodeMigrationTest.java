package edu.bingol.backend.media.transcode;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/** V360 migration dosya kontrolu: aralik, onek, eklemeli degisiklik, surum/indeks adi cakismasi yok. */
class TranscodeMigrationTest {

    static final Path DIR = Path.of("src/main/resources/db/migration");

    static String sql() throws Exception {
        try (InputStream in = TranscodeMigrationTest.class.getResourceAsStream("/db/migration/V360__media_transcode.sql")) {
            assertNotNull(in, "V360__media_transcode.sql siniflar yolunda olmali");
            return new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    @Test
    void v360IsAdditiveAndUsesReservedPrefix() throws Exception {
        String sql = sql();
        String lower = sql.toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");
        for (String col : new String[] {"transcode_status", "wrapped_dek", "encrypted", "transcode_attempts", "transcode_at"}) {
            assertTrue(lower.contains("alter table post_media add column " + col), col);
        }
        assertTrue(lower.contains("alter table message_attachment add column transcode_status"));
        // yikici ifade yok
        assertTrue(!lower.contains("drop ") && !lower.contains("delete from") && !lower.contains("truncate"));
        // eski satirlar icin guvenli varsayilan: encrypted false, durum null
        assertTrue(lower.contains("encrypted boolean not null default false"));
        Matcher m = Pattern.compile("create index (\\w+)", Pattern.CASE_INSENSITIVE).matcher(sql);
        int n = 0;
        while (m.find()) {
            assertTrue(m.group(1).startsWith("trn360_"), "indeks oneki: " + m.group(1));
            n++;
        }
        assertEquals(2, n);
    }

    @Test
    void versionAndIndexNamesAreUniqueAcrossSchema() throws Exception {
        if (!Files.isDirectory(DIR)) {
            return; // farkli calisma dizini: siniflar yolundaki dosya testi yeterli
        }
        Set<String> versions = new HashSet<>();
        Set<String> indexes = new HashSet<>();
        try (Stream<Path> files = Files.list(DIR)) {
            for (Path f : (Iterable<Path>) files.sorted()::iterator) {
                String name = f.getFileName().toString();
                Matcher v = Pattern.compile("^V(\\d+)__").matcher(name);
                if (!v.find()) {
                    continue;
                }
                assertTrue(versions.add(v.group(1)), "yinelenen surum V" + v.group(1));
                Matcher ix = Pattern.compile("create\\s+(?:unique\\s+)?index\\s+(?:if\\s+not\\s+exists\\s+)?(\\w+)",
                        Pattern.CASE_INSENSITIVE).matcher(Files.readString(f, StandardCharsets.UTF_8));
                while (ix.find()) {
                    String idx = ix.group(1).toLowerCase(Locale.ROOT);
                    // eski dosyalarda cakisma yoksa (baska ajanlarin dosyalari dahil) yenisi de cakismamali
                    if (idx.startsWith("trn360_")) {
                        assertTrue(indexes.add(idx), "yinelenen indeks " + idx);
                    }
                }
            }
        }
        assertTrue(versions.contains("360"));
    }
}
