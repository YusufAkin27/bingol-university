package edu.bingol.backend.observability;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.config.StorageCapacityProperties;
import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.dbmaint.admin.RetentionPurgeService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.jdbc.core.JdbcTemplate;

/** Depolama doluluk: esikler, olculen/hesaplanan kaynak ayrimi, uyari gecisleri (spam yok). */
class StorageUsageTest {

    @TempDir Path dir;

    private static ObservabilityProperties props(int warn, int crit) {
        return new ObservabilityProperties(1, 20, 10, 30, 80, 90, 3, 6, 1000, 120, 26, 32, true, "", 60, "", warn, crit);
    }

    /** H2/test: pg_database_size yok; veritabani boyutunu sabitler. */
    private StorageUsageService service(ObservabilityProperties p, StorageCapacityProperties cap, long dbBytes) {
        BackupStatusProvider backup = new BackupStatusProvider(dir.resolve("backups").resolve("last-success.json"));
        return new StorageUsageService(mock(JdbcTemplate.class), new StorageProperties(dir.resolve("uploads").toString()),
                cap, p, backup) {
            @Override
            Database database() {
                return new Database(dbBytes, List.of());
            }
        };
    }

    @Test
    void unknownWhenNeitherDiskPathNorCapacityConfigured() {
        StorageUsageService s = service(props(80, 90), new StorageCapacityProperties(0, "", 0), 1000);
        StorageUsageService.Report r = s.measure();
        assertThat(r.dbServerDisk().source()).isEqualTo("UNKNOWN");
        assertThat(r.dbServerDisk().percent()).isNull();
        // uygulama diskleri statfs ile OLCULUR
        assertThat(r.appDisks()).isNotEmpty();
        assertThat(r.appDisks()).allSatisfy(d -> assertThat(d.source()).isEqualTo("MEASURED"));
    }

    @Test
    void computedFromCapacityUsesDbPlusUploadsPlusBackupsPlusReserved() throws IOException {
        Files.createDirectories(dir.resolve("uploads"));
        Files.createDirectories(dir.resolve("backups"));
        Files.write(dir.resolve("uploads").resolve("a.bin"), new byte[3000]);
        Files.write(dir.resolve("backups").resolve("b.bin"), new byte[2000]);
        // kapasite 10_000: kullanim = 4000 (db) + 3000 + 2000 + 1000 (pay) = 10_000 -> %100
        StorageUsageService s = service(props(80, 90), new StorageCapacityProperties(10_000, "", 1000), 4000);
        StorageUsageService.Disk d = s.measure().dbServerDisk();
        assertThat(d.source()).isEqualTo("COMPUTED");
        assertThat(d.usedBytes()).isEqualTo(10_000L);
        assertThat(d.percent()).isEqualTo(100.0);
        assertThat(d.status()).isEqualTo(IndicatorStatus.CRIT);
    }

    @Test
    void warnAndCritThresholdsApplyToComputedPercent() {
        // %60 kullanim
        StorageCapacityProperties cap = new StorageCapacityProperties(10_000, "", 0);
        assertThat(service(props(80, 90), cap, 6000).measure().dbServerDisk().status()).isEqualTo(IndicatorStatus.OK);
        assertThat(service(props(50, 90), cap, 6000).measure().dbServerDisk().status()).isEqualTo(IndicatorStatus.WARN);
        assertThat(service(props(10, 50), cap, 6000).measure().dbServerDisk().status()).isEqualTo(IndicatorStatus.CRIT);
        // rapor durumu en kotu diskten gelir
        // %99: gercek uygulama disklerinden (olculen) buyuk olmali -> en kotu kaynak db-server
        StorageUsageService.Report r = service(props(10, 50), cap, 9900).measure();
        assertThat(r.status()).isEqualTo(IndicatorStatus.CRIT);
        assertThat(r.worstKey()).isEqualTo("db-server");
        assertThat(r.worstPercent()).isEqualTo(99.0);
    }

    @Test
    void measuredWhenDbDiskPathGiven() {
        StorageUsageService s = service(props(80, 90), new StorageCapacityProperties(0, dir.toString(), 0), 1000);
        StorageUsageService.Disk d = s.measure().dbServerDisk();
        assertThat(d.source()).isEqualTo("MEASURED");
        assertThat(d.percent()).isNotNull();
        assertThat(d.totalBytes()).isPositive();
    }

    @Test
    void lowThresholdProducesWarnOnRealMeasuredDisk() {
        // her gercek disk >= %0,1 dolu: esik 0 -> kademe kapali; 1 -> uyari beklenir
        StorageUsageService s = service(props(1, 100), new StorageCapacityProperties(0, dir.toString(), 0), 1000);
        assertThat(s.measure().status()).isIn(IndicatorStatus.WARN, IndicatorStatus.OK);
        StorageUsageService.Disk d = s.measure().dbServerDisk();
        assertThat(d.status()).isEqualTo(d.percent() >= 1 ? IndicatorStatus.WARN : IndicatorStatus.OK);
    }

    // ---- uyari isi ----

    @Test
    void worsenedOnlyOnEscalation() {
        assertThat(StorageAlertJob.worsened(null, IndicatorStatus.WARN)).isTrue();
        assertThat(StorageAlertJob.worsened("OK", IndicatorStatus.CRIT)).isTrue();
        assertThat(StorageAlertJob.worsened("UNKNOWN", IndicatorStatus.WARN)).isTrue();
        assertThat(StorageAlertJob.worsened("WARN", IndicatorStatus.CRIT)).isTrue();
        assertThat(StorageAlertJob.worsened("WARN", IndicatorStatus.WARN)).isFalse();
        assertThat(StorageAlertJob.worsened("CRIT", IndicatorStatus.CRIT)).isFalse();
        assertThat(StorageAlertJob.worsened("CRIT", IndicatorStatus.WARN)).isFalse();
        assertThat(StorageAlertJob.worsened("WARN", IndicatorStatus.OK)).isFalse();
    }

    @Test
    @SuppressWarnings("unchecked")
    void notifiesAdminsOnTransitionAndThrottlesRepeats() {
        StorageUsageService usage = mock(StorageUsageService.class);
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        UserRepository users = mock(UserRepository.class);
        UserRepository.UserLang admin = mock(UserRepository.UserLang.class);
        when(admin.getId()).thenReturn(5L);
        when(users.audienceAdmins()).thenReturn(List.of(admin));
        NotificationService notifications = mock(NotificationService.class);
        StorageAlertJob job = new StorageAlertJob(usage, redis, mock(SchedulerLock.class), users, notifications,
                mock(RetentionPurgeService.class));

        // 1) OK -> WARN: bildirim
        when(usage.fresh()).thenReturn(report(IndicatorStatus.WARN, 85.0));
        when(ops.get("ds:storage:state")).thenReturn("OK");
        job.check();
        verify(notifications, times(1)).sendTemplated(eq(5L), eq(NotificationType.SYSTEM), eq("obs.storageWarn"), any(), eq("85.0"));

        // 2) WARN -> WARN, 24 saatlik tekrar kapisi KAPALI (anahtar var): bildirim yok
        when(ops.get("ds:storage:state")).thenReturn("WARN");
        when(ops.setIfAbsent(eq("ds:storage:repeat"), anyString(), any(Duration.class))).thenReturn(false);
        job.check();
        verify(notifications, times(1)).sendTemplated(any(), any(), anyString(), any(), anyString());

        // 3) WARN -> CRIT: yeniden bildirim (kritik sablon)
        when(usage.fresh()).thenReturn(report(IndicatorStatus.CRIT, 93.0));
        job.check();
        verify(notifications).sendTemplated(eq(5L), eq(NotificationType.SYSTEM), eq("obs.storageCrit"), any(), eq("93.0"));

        // 4) ayni seviyede 24 saat gecti (kapi acik): gunluk tekrar
        when(ops.get("ds:storage:state")).thenReturn("CRIT");
        when(ops.setIfAbsent(eq("ds:storage:repeat"), anyString(), any(Duration.class))).thenReturn(true);
        job.check();
        verify(notifications, times(2)).sendTemplated(eq(5L), eq(NotificationType.SYSTEM), eq("obs.storageCrit"), any(), eq("93.0"));

        // 5) duzeldi: bildirim yok, tekrar kapisi sifirlanir
        when(usage.fresh()).thenReturn(report(IndicatorStatus.OK, 40.0));
        job.check();
        verify(redis).delete("ds:storage:repeat");
        verify(notifications, never()).sendTemplated(any(), any(), eq("obs.storageOk"), any(), any());
    }

    private static StorageUsageService.Report report(IndicatorStatus st, double pct) {
        return new StorageUsageService.Report(java.time.Instant.now(), st, pct, "db-server",
                new StorageUsageService.Database(1L, List.of()), null, List.of(), 80, 90);
    }
}
