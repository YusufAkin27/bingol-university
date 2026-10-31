package edu.bingol.backend.observability;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.config.StorageCapacityProperties;
import edu.bingol.backend.config.StorageProperties;
import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.jdbc.core.JdbcTemplate;

/** T-075 (A2-17): agir depolama olcumu dakikada bir degil, onbellek suresi (5 dk) icinde tek kez yapilir. */
class StorageReportCacheTest {

    @TempDir Path dir;

    @Test
    void reportIsCachedForFiveMinutesAndFreshBypasses() {
        AtomicInteger dbCalls = new AtomicInteger();
        ObservabilityProperties p = new ObservabilityProperties(1, 20, 10, 30, 80, 90, 3, 6, 1000, 120, 26, 32, true, "",
                60, "", 80, 90);
        StorageUsageService s = new StorageUsageService(mock(JdbcTemplate.class),
                new StorageProperties(dir.resolve("uploads").toString()), new StorageCapacityProperties(0, "", 0), p,
                new BackupStatusProvider(dir.resolve("backups").resolve("last-success.json"))) {
            @Override
            Database database() {
                dbCalls.incrementAndGet();
                return new Database(1000L, List.of());
            }
        };

        assertThat(StorageUsageService.REPORT_TTL_MS).isGreaterThanOrEqualTo(300_000);
        // alarm dongusu dakikada bir okur: 6 okuma tek olcum
        for (int i = 0; i < 6; i++) {
            s.report();
        }
        assertThat(dbCalls.get()).isEqualTo(1);
        s.fresh();
        assertThat(dbCalls.get()).isEqualTo(2);
    }
}
