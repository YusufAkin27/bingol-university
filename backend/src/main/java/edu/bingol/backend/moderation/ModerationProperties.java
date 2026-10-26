package edu.bingol.backend.moderation;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.moderation.*`
 * <ul>
 *   <li>auto-hide-threshold: ayni hedefe bu kadar BAGIMSIZ (farkli, yeterince eski hesapli) raporlayici olunca gecici gizleme; 0 = kapali</li>
 *   <li>new-account-min-age-hours: bundan yeni hesaplarin raporu esige sayilmaz (sahte hesapla gizleme istismari)</li>
 *   <li>strike-suspend-threshold / strike-window-days: pencere icinde bu kadar ihlalde askiya alma onerisi; 0 = kapali</li>
 *   <li>reject-restrict-threshold / reject-window-days / restrict-days: pencerede bu kadar reddedilen rapor yapana rapor kisiti; 0 = kapali</li>
 *   <li>re-report-block-days: ayni hedefe ayni kisi bu surede tekrar rapor veremez</li>
 * </ul>
 */
@ConfigurationProperties("app.moderation")
public record ModerationProperties(
        @DefaultValue("3") int autoHideThreshold,
        @DefaultValue("24") int newAccountMinAgeHours,
        @DefaultValue("3") int strikeSuspendThreshold,
        @DefaultValue("180") int strikeWindowDays,
        @DefaultValue("5") int rejectRestrictThreshold,
        @DefaultValue("30") int rejectWindowDays,
        @DefaultValue("7") int restrictDays,
        @DefaultValue("30") int reReportBlockDays) {
}
