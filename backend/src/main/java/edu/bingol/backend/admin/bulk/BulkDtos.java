package edu.bingol.backend.admin.bulk;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;

/** P15: haber / akademik / menu / bekleyen kayit toplu islem sozlesmesi (ortak rapor + istekler). */
public final class BulkDtos {

    /** Haber ve akademik toplu islemde tek seferde en fazla kayit. */
    public static final int MAX_IDS = 200;
    /** Menu toplu silmede en fazla gun (iki ay). */
    public static final int MAX_DATES = 62;
    /** CSV dis aktarma satir ust siniri. */
    public static final int MAX_EXPORT_ROWS = 50_000;
    /** En kisa sebep (AdminGuardPolicy.DEFAULT_MIN_REASON ile ayni). */
    public static final int MIN_REASON = 5;

    private BulkDtos() {}

    public enum NewsAction { HIDE, UNHIDE }

    public enum AcademicEntity { CALENDAR, EXAM, ANNOUNCEMENT }

    public enum AcademicAction { PUBLISH, UNPUBLISH, DELETE }

    public enum SourceName { NEWS, MENU }

    public record NewsBulkRequest(@NotNull NewsAction action, @NotNull List<Long> ids, @Size(max = 300) String reason) {}

    public record AcademicBulkRequest(@NotNull AcademicEntity entity, @NotNull AcademicAction action,
                                      @NotNull List<Long> ids, @Size(max = 300) String reason) {}

    public record MenuBulkDeleteRequest(@NotNull List<String> dates, @Size(max = 300) String reason) {}

    /** Kimlik e-posta ya da okul numarasi olabilir (tek tek `LoginIdentifier` ile normalize edilir). */
    public record PendingBulkCancelRequest(@NotNull List<String> emails, @Size(max = 300) String reason) {}

    public record SourceSyncRequest(@NotNull SourceName source, @Size(max = 300) String reason) {}

    /** Tek kaydin sonucu: status DONE | SKIPPED | FAILED; code bos ya da neden (ALREADY_DONE, NOT_FOUND, hata kodu). */
    public record Result(String id, String status, String code) {}

    /** Kismi basari raporu: skipped = yapilacak is yoktu (zaten o durumda ya da kayit yok), failed = hata. */
    public record Report(int requested, int done, int skipped, int failed, List<Result> results) {}

    public record SyncResult(String source, int changed, Map<String, Integer> detail) {}

    public record NewsSourceStatus(boolean maintenance, String lastSuccess, String lastAttempt, String message,
                                   long itemsLast7d, long total, long hidden, Map<String, Long> byType) {}

    public record MenuSourceStatus(boolean maintenance, String lastSuccess, String lastAttempt, String message,
                                   long totalDays, long upcomingDays, long withImage) {}

    public record SourcesStatus(NewsSourceStatus news, MenuSourceStatus menu, int syncPerHour) {}
}
