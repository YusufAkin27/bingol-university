package edu.bingol.backend.observability;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** GDRIVE-BACKUP: durum dosyasindan yedek raporu (yeni alanlar, eski biçim uyumu, sirsizlik). */
class BackupReportTest {

    @TempDir Path dir;

    private BackupStatusProvider with(String json) throws Exception {
        Path f = dir.resolve("last-success.json");
        Files.writeString(f, json);
        return new BackupStatusProvider(f);
    }

    private static final String FULL = "{\"lastSuccessAt\":\"2026-11-01T10:05:09Z\",\"time\":\"2026-11-01T10:05:09Z\","
            + "\"file\":\"20261101T130500\",\"sizeBytes\":485280,\"durationSec\":3,\"dbOk\":true,\"filesOk\":true,"
            + "\"local\":{\"count\":3,\"bytes\":1500000,\"oldestAt\":\"2026-11-01T08:05:00Z\"},"
            + "\"remote\":{\"configured\":true,\"kind\":\"drive\",\"name\":\"gdrive\",\"lastSuccessAt\":\"2026-11-01T00:40:12Z\","
            + "\"lastVerifiedAt\":\"2026-11-01T00:40:30Z\",\"lastError\":null,\"bytes\":7340032,\"count\":6},"
            + "\"schedule\":{\"cron\":\"5 * * * *\",\"verifyCron\":\"30 4 * * 0\",\"remoteCron\":\"35 3 * * *\"},"
            + "\"retention\":{\"localDaily\":3,\"localWeekly\":0,\"localMonthly\":0,"
            + "\"remoteDaily\":7,\"remoteWeekly\":4,\"remoteMonthly\":6}}";

    @Test
    void parsesNewFormat() throws Exception {
        BackupReport r = with(FULL).report();
        assertThat(r.lastSuccessAt()).isEqualTo(Instant.parse("2026-11-01T10:05:09Z"));
        assertThat(r.lastStatus()).isEqualTo("OK");
        assertThat(r.local().count()).isEqualTo(3L);
        assertThat(r.local().bytes()).isEqualTo(1_500_000L);
        assertThat(r.local().oldestAt()).isEqualTo(Instant.parse("2026-11-01T08:05:00Z"));
        BackupReport.Remote rm = r.remote();
        assertThat(rm.configured()).isTrue();
        assertThat(rm.kind()).isEqualTo("drive");
        assertThat(rm.name()).isEqualTo("gdrive");
        assertThat(rm.lastSuccessAt()).isEqualTo(Instant.parse("2026-11-01T00:40:12Z"));
        assertThat(rm.lastVerifiedAt()).isEqualTo(Instant.parse("2026-11-01T00:40:30Z"));
        assertThat(rm.lastError()).isNull();
        assertThat(rm.bytes()).isEqualTo(7_340_032L);
        assertThat(rm.count()).isEqualTo(6L);
        assertThat(r.schedule().cron()).isEqualTo("5 * * * *");
        assertThat(r.schedule().verifyCron()).isEqualTo("30 4 * * 0");
        assertThat(r.schedule().remoteCron()).isEqualTo("35 3 * * *");
        assertThat(r.retention().localDaily()).isEqualTo(3);
        assertThat(r.retention().remoteMonthly()).isEqualTo(6);
    }

    @Test
    void legacyFormatWithoutRemoteIsNotConfigured() throws Exception {
        BackupReport r = with("{\"lastSuccessAt\":\"2026-10-28T10:52:20Z\",\"time\":\"2026-10-28T10:52:20Z\","
                + "\"file\":\"20261028T135217\",\"sizeBytes\":485280,\"durationSec\":3,\"dbOk\":true,\"filesOk\":true}").report();
        assertThat(r.lastSuccessAt()).isEqualTo(Instant.parse("2026-10-28T10:52:20Z"));
        assertThat(r.lastStatus()).isEqualTo("OK");
        assertThat(r.remote().configured()).isFalse();
        assertThat(r.remote().kind()).isNull();
        assertThat(r.remote().name()).isNull();
        assertThat(r.remote().bytes()).isNull();
        assertThat(r.local().count()).isNull();
        assertThat(r.schedule().cron()).isNull();
        assertThat(r.retention().remoteDaily()).isNull();
        // eski okuyucu davranisi bozulmaz
        assertThat(with("{\"lastSuccessAt\":\"2026-10-28T10:52:20Z\"}").lastSuccess())
                .contains(Instant.parse("2026-10-28T10:52:20Z"));
    }

    @Test
    void nestedRemoteTimeIsNeverTakenAsBackupTime() throws Exception {
        // ust duzey lastSuccessAt yoksa (yalniz uzak durum yazilmissa) yedek zamani BILINMEZ; remote.lastSuccessAt sayilmaz
        BackupStatusProvider p = with("{\"remote\":{\"configured\":true,\"kind\":\"drive\",\"name\":\"gd\","
                + "\"lastSuccessAt\":\"2026-11-01T00:40:12Z\"}}");
        assertThat(p.lastSuccess()).isEmpty();
        BackupReport r = p.report();
        assertThat(r.lastSuccessAt()).isNull();
        assertThat(r.lastStatus()).isNull();
        assertThat(r.remote().lastSuccessAt()).isEqualTo(Instant.parse("2026-11-01T00:40:12Z"));
    }

    @Test
    void missingOrGarbageFileIsUnknownNotAnError() throws Exception {
        BackupReport missing = new BackupStatusProvider(dir.resolve("yok.json")).report();
        assertThat(missing.lastSuccessAt()).isNull();
        assertThat(missing.remote().configured()).isFalse();
        assertThat(missing.local().count()).isNull();
        BackupReport garbage = with("{not json").report();
        assertThat(garbage.remote().configured()).isFalse();
        assertThat(garbage.lastStatus()).isNull();
    }

    @Test
    void failureRecordNewerThanSuccessMeansFailed() throws Exception {
        BackupStatusProvider p = with("{\"lastSuccessAt\":\"2026-11-01T10:05:09Z\"}");
        assertThat(p.report().lastStatus()).isEqualTo("OK");
        Files.writeString(dir.resolve("last-failure.json"), "{\"time\":\"2026-11-01T11:05:09Z\",\"error\":\"x\"}");
        assertThat(p.report().lastStatus()).isEqualTo("FAILED");
        // eski biçim (yerel saat, iki nokta yok) de okunur; basarili yedekten ESKI bir kayit durumu bozmaz
        Files.writeString(dir.resolve("last-failure.json"), "{\"time\":\"2026-11-01T09:00:00+0000\",\"error\":\"x\"}");
        assertThat(p.report().lastStatus()).isEqualTo("OK");
        Files.writeString(dir.resolve("last-failure.json"), "{\"time\":\"2026-11-01T12:00:00+0300\",\"error\":\"x\"}");
        assertThat(p.report().lastStatus()).isEqualTo("OK");   // 12:00+03:00 = 09:00Z < 10:05:09Z
        Files.writeString(dir.resolve("last-failure.json"), "{\"time\":\"2026-11-01T14:00:00+0300\",\"error\":\"x\"}");
        assertThat(p.report().lastStatus()).isEqualTo("FAILED");   // 14:00+03:00 = 11:00Z > 10:05:09Z
    }

    @Test
    void pathLikeRemoteNameAndUnknownKindAreNeutralised() throws Exception {
        BackupReport r = with("{\"lastSuccessAt\":\"2026-11-01T10:05:09Z\",\"remote\":{\"configured\":true,"
                + "\"kind\":\"weird\",\"name\":\"gdrive:BU-Kampus-Yedek/gizli\"}}").report();
        assertThat(r.remote().configured()).isTrue();
        assertThat(r.remote().name()).isNull();
        assertThat(r.remote().kind()).isEqualTo("other");
    }

    @Test
    void errorTextIsOneShortLine() throws Exception {
        String longErr = "a".repeat(500);
        BackupReport r = with("{\"remote\":{\"configured\":true,\"kind\":\"other\",\"name\":\"s3\","
                + "\"lastError\":\"" + longErr + "\\nikinci satir\"}}").report();
        assertThat(r.remote().lastError()).hasSize(200).doesNotContain("\n");
    }
}
