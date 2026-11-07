package edu.bingol.backend.observability;

import java.time.Instant;

/**
 * {@code GET /api/admin/system/backup} yaniti (yonetim paneli sozlesmesi; bilinmeyen alan {@code null}, tarihler ISO-8601 UTC).
 * Kaynak: yedek ajaninin yazdigi {@code last-success.json} ({@link BackupStatusProvider}); bu sinif yalniz bicimdir.
 * Uzak hedefin yolu/belirteci hicbir alanda YOKTUR: yalniz rclone uzak adi ({@code remote.name}).
 */
public record BackupReport(
        Local local,
        Remote remote,
        Instant lastSuccessAt,
        /** OK | FAILED | null (bilinmiyor). FAILED: son basarili yedekten sonra bir yedek denemesi basarisiz oldu. */
        String lastStatus,
        Schedule schedule,
        Retention retention) {

    /** Sunucudaki yerel yedekler (damga basina bir). */
    public record Local(Long count, Long bytes, Instant oldestAt) {
    }

    /** Uzak kopya (Google Drive vb.). configured=false ise diger alanlar null. kind: drive | other. */
    public record Remote(boolean configured, String kind, String name, Instant lastSuccessAt, Instant lastVerifiedAt,
                         String lastError, Long bytes, Long count) {
    }

    /** cron ifadeleri (konteyner saati Europe/Istanbul). remoteCron: uzak yukleme (uzak kopya kapaliysa null). */
    public record Schedule(String cron, String verifyCron, String remoteCron) {
    }

    public record Retention(Integer localDaily, Integer localWeekly, Integer localMonthly,
                            Integer remoteDaily, Integer remoteWeekly, Integer remoteMonthly) {
    }

    /** Durum dosyasi yok/okunamaz: hicbir sey bilinmiyor. */
    public static BackupReport unknown() {
        return new BackupReport(new Local(null, null, null),
                new Remote(false, null, null, null, null, null, null, null), null, null,
                new Schedule(null, null, null), new Retention(null, null, null, null, null, null));
    }
}
