package edu.bingol.backend.notification.admin;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;

/**
 * Yonetici push altyapisi (P14) yanit/istek sekilleri. Hicbir yanit push YUKUNU (baslik/govde/veri), ham FCM token'ini ya da
 * tam kullanici kimligini icermez: hedef yalniz maskeli gosterilir (bkz. {@link PushMask}).
 */
public final class PushAdminDtos {

    private PushAdminDtos() {}

    /** Kuyruk listesi satiri. targetRef: token ozetinin ilk 8 hanesi; userRef: maskeli kullanici kimligi. */
    public record OutboxRow(Long id, String status, String type, Long campaignId, String targetRef, String userRef,
                            int attempts, String errorCode, String nextAttemptAt, String createdAt, String sentAt) {}

    /** Kuyruk kaydi ayrintisi (yuk YOK). canRetry/canCancel: bu durumda hangi islem yapilabilir. */
    public record OutboxDetail(Long id, String status, String type, Long campaignId, String targetRef, String userRef,
                               int attempts, int maxAttempts, String errorCode, String lastError, int priority,
                               String nextAttemptAt, String leaseUntil, String createdAt, String sentAt,
                               boolean canRetry, boolean canCancel) {}

    public record ActionResult(Long id, String status) {}

    public enum BulkAction { RETRY, CANCEL }

    /** ids en cok 200 (servis denetler); sebep X-Admin-Reason basligi ya da govdedeki reason ile gelir. */
    public record BulkRequest(@NotNull BulkAction action, @NotNull @Size(min = 1) List<Long> ids,
                              @Size(max = 300) String reason) {}

    public record BulkFailure(Long id, String code) {}

    /** Kismi basari: succeeded islenenler, failed her kimlik icin neden kodu (NOT_FOUND | INVALID_STATE). */
    public record BulkResult(BulkAction action, int requested, int succeeded, List<BulkFailure> failed) {}

    /** Cihaz ozeti: yalniz toplu sayilar. byPlatform anahtarlari: android, ios, web, other. */
    public record DeviceSummary(long totalTokens, long usersWithDevice, Map<String, Long> byPlatform,
                                List<VersionCount> byAppVersion, long activeLast7d, long staleOver30d) {}

    public record VersionCount(String version, long count) {}

    /** Kampanya hata grubu: ayni durum + FCM hata kodundaki kayit sayisi. */
    public record FailureGroup(String errorCode, String status, long count, String lastAt) {}

    /**
     * Kampanyanin kuyruk ozeti. totals: durum -> sayi (tum durumlar); groups: yalniz DEAD/FAILED, sayiya gore azalan (en cok 200).
     * linked: kampanyaya bagli kuyruk kaydi var mi (surum oncesi kampanyalarda kayit baglanmamistir).
     */
    public record CampaignFailures(Long campaignId, boolean linked, Map<String, Long> totals,
                                   List<FailureGroup> groups, boolean truncated) {}

    public record DayStat(String date, long created, long read) {}

    public record TypeCount(String type, long count) {}

    /** Global bildirim kutusu istatistigi. readRate: pencere icinde olusanlarin okunma orani (0..1) ya da null. */
    public record NotificationStats(int days, List<DayStat> series, Double readRate, long created, long read,
                                    List<TypeCount> byType, long totalRows, long unreadRows) {}
}
