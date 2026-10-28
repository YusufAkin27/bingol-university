package edu.bingol.backend.mail.admin;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * Yonetici mail altyapisi (P13) istek/yanit tipleri. Hicbir yanitta tam alici adresi (liste), kuyruk icerigi ya da
 * degiskenleri (kod/jeton icerebilir) yoktur.
 */
public final class MailOpsDtos {

    private MailOpsDtos() {}

    /** Sayfa tabanli liste (yonetim listeleri): page 0'dan baslar. */
    public record PageResult<T>(List<T> items, int page, int size, long total, int totalPages) {
        public static <T> PageResult<T> of(List<T> items, int page, int size, long total) {
            int pages = size <= 0 ? 0 : (int) ((total + size - 1) / size);
            return new PageResult<>(items, page, size, total, pages);
        }
    }

    // --- bastirma listesi ---

    /** Liste satiri: adres maskeli; cozulemiyorsa emailMasked null + hashPrefix (ilk 10 hane). */
    public record SuppressionRow(Long id, String emailMasked, String hashPrefix, String reason, String category,
                                 String note, String createdAt, Long createdBy, boolean userOptOut) {}

    /**
     * Ayrinti: adres yalniz bir kullanici hesabi bu ozetle eslesiyorsa TAM gosterilir (ozetten geri cevrilemez);
     * aksi halde fullEmail null. removeMinReason/removeNeedsConfirm kaldirma kurallarini istemciye bildirir.
     */
    public record SuppressionDetail(Long id, String emailMasked, String fullEmail, boolean fullEmailResolved,
                                    Long userId, String hashPrefix, String reason, String category, String note,
                                    String createdAt, Long createdBy, boolean userOptOut, int removeMinReason,
                                    boolean removeNeedsConfirm, String removeWarning) {}

    /** reason: yalniz "MANUAL" (ya da bos). note: ZORUNLU sebep (en az 5). */
    public record SuppressionCreate(@NotBlank @Size(max = 254) String email, @Size(max = 16) String reason,
                                    @NotBlank @Size(min = 5, max = 300) String note) {}

    // --- kuyruk ---

    public record OutboxRow(Long id, String status, String template, String category, String toMasked, String lang,
                            int attempts, String nextAttemptAt, String createdAt, String sentAt, String lastError,
                            boolean retryable, boolean cancellable) {}

    public record TimelineEvent(String at, String event, String detail) {}

    /** Ayrinti: durum, deneme, hata, sonraki deneme. ICERIK ve degiskenler YOKTUR (contentIncluded=false). */
    public record OutboxDetail(Long id, String status, String template, String category, String toMasked, String lang,
                               int attempts, String nextAttemptAt, String createdAt, String sentAt, String lastError,
                               boolean retryable, String retryBlockedCode, boolean cancellable, boolean contentCleared,
                               boolean contentIncluded, List<TimelineEvent> timeline, List<String> warnings) {}

    public record BulkRequest(@NotNull String action, @NotNull @Size(min = 1, max = 200) List<Long> ids,
                              @NotBlank @Size(min = 5, max = 300) String reason) {}

    public record BulkFailure(Long id, String code) {}

    public record BulkResult(String action, int requested, int succeeded, List<BulkFailure> failed) {}

    // --- kota ---

    public record QuotaDay(String date, long used) {}

    public record QueueCounts(long pending, long failed, long dead, long skipped, String oldestPendingAt) {}

    public record QuotaView(boolean mailEnabled, boolean enabled, int limit, int reserve, int announcementCap,
                            long used, long remaining, long announcementRemaining, double percent, String level,
                            int resetHourUtc, String dayStart, String nextReset, long publicCodeUsed,
                            int publicCodeCapRegistration, int publicCodeCapReset, int maxCodesPerEmailPerDay,
                            int maxCodeRequestsPerIpPerDay, List<QuotaDay> history, String historyNote,
                            QueueCounts queue) {}
}
