package edu.bingol.backend.observability;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.observability.*`: sistem durumu esikleri ve yonetici uyarisi.
 *
 * <p>Kuyruk: olu (DEAD) kayit sayisi {@code deadWarn} ve ustu WARN, {@code deadCrit} ustu CRIT; en eski bekleyen kayit
 * {@code queueAgeWarnMinutes} ustu WARN, {@code queueAgeCritMinutes} ustu CRIT. Yedek (saatlik): {@code backupWarnHours}
 * ustu WARN, {@code backupCritHours} ustu CRIT. Disk doluluk yuzdesi {@code diskWarnPercent}/{@code diskCritPercent}.
 */
@ConfigurationProperties("app.observability")
public record ObservabilityProperties(
        @DefaultValue("1") int deadWarn,
        @DefaultValue("20") int deadCrit,
        @DefaultValue("10") int queueAgeWarnMinutes,
        @DefaultValue("30") int queueAgeCritMinutes,
        @DefaultValue("80") int diskWarnPercent,
        @DefaultValue("90") int diskCritPercent,
        @DefaultValue("3") int backupWarnHours,
        @DefaultValue("6") int backupCritHours,
        @DefaultValue("1000") long dbWarnMillis,
        /** Sik calisan (saniyeler) zamanlayicilarin (kuyruk isleyicileri) son basari yasi: WARN; 3 kati CRIT. */
        @DefaultValue("120") int pollerMaxAgeSeconds,
        /** Gecelik gorevler: son basarili calisma bu kadar saati asarsa WARN; 2 kati CRIT. */
        @DefaultValue("26") int nightlyMaxAgeHours,
        /** Aylik gorev (yemek listesi). */
        @DefaultValue("32") int monthlyMaxAgeDays,
        @DefaultValue("true") boolean alertEnabled,
        /** Bos degilse OK->CRIT gecisinde bu adrese de e-posta gider (bildirim her zaman birincildir). */
        @DefaultValue("") String alertEmail,
        @DefaultValue("60") int alertIntervalMinutes,
        /** Yedek durum dosyasi; bos = ${STORAGE_DIR}/../backups/last-success.json (env BACKUP_STATUS_FILE). */
        @DefaultValue("") String backupStatusFile) {
}
