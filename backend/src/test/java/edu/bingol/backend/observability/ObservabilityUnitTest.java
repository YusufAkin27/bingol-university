package edu.bingol.backend.observability;

import static org.assertj.core.api.Assertions.assertThat;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** Gozlemlenebilirlik paketinin saf mantik birim testleri (Spring baglami gerektirmez). */
class ObservabilityUnitTest {

    private static final ObservabilityProperties DEFAULTS = new ObservabilityProperties(1, 20, 10, 30, 80, 90, 3, 6,
            1000, 120, 26, 32, true, "", 60, "", 80, 90);

    @Test
    void alertEmailSubjectUsesCorrectBrandSpelling() {
        // A9-03 / T-124: konu satiri kullaniciya gorunur; dogru yazim "BÜ Kampüs"
        assertThat(SystemAlertService.alertSubject("3")).isEqualTo("[BÜ Kampüs] Sistem uyarısı (CRIT): 3 gösterge");
    }

    // ---- esik kiyasi ----

    @Test
    void byThresholdPicksHighestReachedTier() {
        assertThat(Indicator.byThreshold(0, 1, 5)).isEqualTo(IndicatorStatus.OK);
        assertThat(Indicator.byThreshold(1, 1, 5)).isEqualTo(IndicatorStatus.WARN);
        assertThat(Indicator.byThreshold(5, 1, 5)).isEqualTo(IndicatorStatus.CRIT);
    }

    @Test
    void worseIgnoresUnknownAgainstKnown() {
        assertThat(IndicatorStatus.worse(IndicatorStatus.UNKNOWN, IndicatorStatus.OK)).isEqualTo(IndicatorStatus.OK);
        assertThat(IndicatorStatus.worse(IndicatorStatus.WARN, IndicatorStatus.UNKNOWN)).isEqualTo(IndicatorStatus.WARN);
        assertThat(IndicatorStatus.worse(IndicatorStatus.WARN, IndicatorStatus.CRIT)).isEqualTo(IndicatorStatus.CRIT);
    }

    @Test
    void overallIsUnknownOnlyWhenNothingKnown() {
        Indicator unknown = Indicator.unknown(null);
        assertThat(SystemOverviewService.overall(List.of(unknown, unknown))).isEqualTo(IndicatorStatus.UNKNOWN);
        assertThat(SystemOverviewService.overall(List.of(unknown, Indicator.ok(1, null)))).isEqualTo(IndicatorStatus.OK);
    }

    // ---- yedek ----

    @Test
    void backupThresholdsFollowHourlyBackupPolicy() {
        assertThat(SystemOverviewService.backupStatus(1.0, DEFAULTS)).isEqualTo(IndicatorStatus.OK);
        assertThat(SystemOverviewService.backupStatus(3.0, DEFAULTS)).isEqualTo(IndicatorStatus.OK);
        assertThat(SystemOverviewService.backupStatus(3.5, DEFAULTS)).isEqualTo(IndicatorStatus.WARN);
        assertThat(SystemOverviewService.backupStatus(6.5, DEFAULTS)).isEqualTo(IndicatorStatus.CRIT);
    }

    @Test
    void backupProviderReadsIsoEpochAndPlainFormats(@TempDir Path dir) throws Exception {
        Path f = dir.resolve("last-success.json");
        Files.writeString(f, "{\"lastSuccessAt\":\"2026-10-28T09:00:00Z\"}");
        assertThat(new BackupStatusProvider(f).lastSuccess()).contains(Instant.parse("2026-10-28T09:00:00Z"));

        Files.writeString(f, "{\"status\":\"ok\",\"epochSeconds\":1767225600}");
        assertThat(new BackupStatusProvider(f).lastSuccess()).contains(Instant.ofEpochSecond(1767225600L));

        Files.writeString(f, "{\"timestamp\":1767225600000}");
        assertThat(new BackupStatusProvider(f).lastSuccess()).contains(Instant.ofEpochSecond(1767225600L));

        Files.writeString(f, "1767225600\n");
        assertThat(new BackupStatusProvider(f).lastSuccess()).contains(Instant.ofEpochSecond(1767225600L));
    }

    @Test
    void backupProviderIsUnknownForMissingOrGarbageFile(@TempDir Path dir) throws Exception {
        assertThat(new BackupStatusProvider(dir.resolve("yok.json")).lastSuccess()).isEmpty();
        Path f = dir.resolve("bozuk.json");
        Files.writeString(f, "{not json at all");
        assertThat(new BackupStatusProvider(f).lastSuccess()).isEmpty();
    }

    @Test
    void backupDefaultPathIsSiblingBackupsDirOfStorage() {
        Path p = BackupStatusProvider.resolvePath("", "/srv/app/uploads");
        assertThat(p.getFileName().toString()).isEqualTo("last-success.json");
        assertThat(p.getParent().getFileName().toString()).isEqualTo("backups");
        assertThat(BackupStatusProvider.resolvePath("/x/y.json", "/srv/app/uploads")).isEqualTo(Path.of("/x/y.json"));
    }

    // ---- zamanlayici izleme ----

    @Test
    void jobMonitorTracksSuccessFailureAndCounts() {
        JobMonitor m = new JobMonitor(new SimpleMeterRegistry());
        Instant t0 = Instant.parse("2026-10-28T10:00:00Z");
        m.recordSuccess("A.run", t0);
        m.recordFailure("A.run", t0.plusSeconds(5));
        Optional<JobMonitor.Stat> s = m.stat("A.run");
        assertThat(s).isPresent();
        assertThat(s.get().lastSuccess()).isEqualTo(t0);
        assertThat(s.get().lastError()).isEqualTo(t0.plusSeconds(5));
        assertThat(s.get().runs()).isEqualTo(2);
        assertThat(s.get().errors()).isEqualTo(1);
        assertThat(m.stat("B.run")).isEmpty();
    }

    @Test
    void jobStatusStaleAndErrorRules() {
        Instant now = Instant.parse("2026-10-28T10:00:00Z");
        long max = 120;
        JobMonitor.Stat fresh = new JobMonitor.Stat(now.minusSeconds(30), null, 5, 0);
        assertThat(SystemOverviewService.jobStatus(fresh, now, max, 3)).isEqualTo(IndicatorStatus.OK);
        JobMonitor.Stat stale = new JobMonitor.Stat(now.minusSeconds(200), null, 5, 0);
        assertThat(SystemOverviewService.jobStatus(stale, now, max, 3)).isEqualTo(IndicatorStatus.WARN);
        JobMonitor.Stat dead = new JobMonitor.Stat(now.minusSeconds(400), null, 5, 0);
        assertThat(SystemOverviewService.jobStatus(dead, now, max, 3)).isEqualTo(IndicatorStatus.CRIT);
        JobMonitor.Stat errAfter = new JobMonitor.Stat(now.minusSeconds(30), now.minusSeconds(10), 5, 1);
        assertThat(SystemOverviewService.jobStatus(errAfter, now, max, 3)).isEqualTo(IndicatorStatus.WARN);
        JobMonitor.Stat errBefore = new JobMonitor.Stat(now.minusSeconds(10), now.minusSeconds(30), 5, 1);
        assertThat(SystemOverviewService.jobStatus(errBefore, now, max, 3)).isEqualTo(IndicatorStatus.OK);
        JobMonitor.Stat neverOk = new JobMonitor.Stat(null, now, 1, 1);
        assertThat(SystemOverviewService.jobStatus(neverOk, now, max, 3)).isEqualTo(IndicatorStatus.WARN);
    }

    // ---- uyari karari ----

    @Test
    void alertOnlyOnTransitionIntoCrit() {
        assertThat(SystemAlertService.shouldAlert("OK", IndicatorStatus.CRIT)).isTrue();
        assertThat(SystemAlertService.shouldAlert("WARN", IndicatorStatus.CRIT)).isTrue();
        assertThat(SystemAlertService.shouldAlert(null, IndicatorStatus.CRIT)).isTrue();
        assertThat(SystemAlertService.shouldAlert("CRIT", IndicatorStatus.CRIT)).isFalse();
        assertThat(SystemAlertService.shouldAlert("OK", IndicatorStatus.WARN)).isFalse();
        assertThat(SystemAlertService.shouldAlert("CRIT", IndicatorStatus.OK)).isFalse();
    }

    // ---- maskeleme ve korelasyon kimligi ----

    @Test
    void maskingHidesEmailsTokensAndSecrets() {
        assertThat(LogMasking.email("ali.veli@bingol.edu.tr")).isEqualTo("a***@bingol.edu.tr");
        assertThat(LogMasking.email(null)).isEqualTo("?");
        String s = LogMasking.scrub("Gonderilemedi ali.veli@bingol.edu.tr token=abc123 Bearer eyJhbGciOi.payloadpart.sig");
        assertThat(s).doesNotContain("ali.veli").doesNotContain("abc123").doesNotContain("payloadpart");
        assertThat(s).contains("a***@bingol.edu.tr");
        assertThat(LogMasking.scrub(null)).isNull();
    }

    @Test
    void requestIdAcceptsSafeIncomingAndRejectsInjection() {
        assertThat(RequestIdFilter.resolve("abc-12345_XYZ.9")).isEqualTo("abc-12345_XYZ.9");
        String generated = RequestIdFilter.resolve("bad\r\nid: x");
        assertThat(generated).hasSize(36).doesNotContain("\n");
        assertThat(RequestIdFilter.resolve(null)).hasSize(36);
        assertThat(RequestIdFilter.resolve("kisa")).hasSize(36);
    }

    @Test
    void defaultsAreSane() {
        assertThat(Duration.ofMinutes(DEFAULTS.queueAgeCritMinutes())).isEqualTo(Duration.ofMinutes(30));
        assertThat(Map.of("k", 1)).isNotEmpty();
    }
}
