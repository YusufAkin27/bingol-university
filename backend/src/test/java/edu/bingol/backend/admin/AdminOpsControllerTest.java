package edu.bingol.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class AdminOpsControllerTest {

    @TempDir
    Path dir;

    @Test
    void missingFileIsUnknown() {
        var s = AdminOpsController.readBackup(dir.resolve("yok"), 36, Instant.now());
        assertThat(s.status()).isEqualTo("UNKNOWN");
        assertThat(s.lastSuccessAt()).isNull();
    }

    @Test
    void metricLineIsParsed() throws Exception {
        Instant now = Instant.parse("2026-10-27T12:00:00Z");
        Path f = dir.resolve("m");
        Files.writeString(f, "# HELP x\nbackup_last_success_timestamp_seconds "
                + (now.getEpochSecond() - 3600) + "\n");
        var s = AdminOpsController.readBackup(f, 36, now);
        assertThat(s.status()).isEqualTo("OK");
        assertThat(s.lastSuccessAt()).isEqualTo(now.minusSeconds(3600));
    }

    @Test
    void staleBackupFails() throws Exception {
        Instant now = Instant.parse("2026-10-27T12:00:00Z");
        Path f = dir.resolve("m");
        Files.writeString(f, "backup_last_success_timestamp_seconds " + (now.getEpochSecond() - 48 * 3600) + "\n");
        var s = AdminOpsController.readBackup(f, 36, now);
        assertThat(s.status()).isEqualTo("FAILED");
        assertThat(s.message()).isNotNull();
    }

    @Test
    void plainFileUsesMtime() throws Exception {
        Path f = dir.resolve("last_success");
        Files.writeString(f, "ok");
        var s = AdminOpsController.readBackup(f, 36, Instant.now());
        assertThat(s.status()).isEqualTo("OK");
    }

    @Test
    void componentNamesAreNormalized() {
        assertThat(AdminOpsController.componentName("dbHealthIndicator")).isEqualTo("db");
        assertThat(AdminOpsController.componentName("redisHealthContributor")).isEqualTo("redis");
        assertThat(AdminOpsController.componentName("mailQueue")).isEqualTo("mailQueue");
    }
}
