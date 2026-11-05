package edu.bingol.backend.forum.admin;

import java.util.List;
import java.util.Map;

/**
 * Yonetim paneli (web) forum yanit sekilleri. ANONIM icerikte yazar kimligi HICBIR alanda yer almaz
 * ({@code author == null}, {@code anonymous == true}); moderator yalniz icerige eylem uygular.
 */
public final class ForumAdminDtos {

    private ForumAdminDtos() {}

    /** Gorunur yazar (yalniz anonim OLMAYAN icerik): kimlik + gorunen ad. E-posta/avatar yok. */
    public record AuthorRef(Long userId, String displayName) {}

    public record CategoryRef(Long id, String name) {}

    /**
     * Sayfa. {@code page} 0 tabanlidir; {@code nextCursor} sonraki sayfa numarasi (metin) ya da null: istemci ya
     * {@code ?page=} ya da {@code ?cursor=nextCursor} ile ilerler. {@code total}/{@code totalItems}/{@code totalPages}
     * yalniz konu listesinde dolu (sikayet ve islem kaydi listelerinde null).
     */
    public record AdminPage<T>(List<T> items, String nextCursor, int page, int size, boolean hasNext, Long total,
                               Long totalItems, Integer totalPages) {
        public static <T> AdminPage<T> of(List<T> items, String nextCursor, int page, int size, boolean hasNext, Long total) {
            Integer pages = total == null ? null : (int) Math.max(1, (total + size - 1) / size);
            return new AdminPage<>(items, nextCursor, page, size, hasNext, total, total, pages);
        }
    }

    /** Sikayet kuyrugunda icerik onizlemesi. {@code author} yalniz anonim OLMAYAN icerikte dolu. */
    public record ReportPreview(String title, String body, boolean anonymous, AuthorRef author, String contentStatus,
                                boolean pinned, boolean locked) {}

    /**
     * Sikayet kuyrugu satiri = bir HEDEF (konu/yorum). {@code id}: hedefin en eski ACIK sikayet kimligi (acik yoksa en
     * son sikayet); {@code POST /api/admin/forum/reports/{id}/resolve} (ya da mevcut {@code /api/admin/reports/{id}/resolve})
     * ile karar verilir ve karar hedefin TUM acik sikayetlerini kapatir (HIDE hedefi kaldirir, DISMISS otomatik
     * gizlenmisse geri acar). {@code resolveReportId}: acik sikayet yoksa null. {@code reasons}: acik sikayet sebepleri
     * (cok olandan aza), {@code reasonCounts}: sebep -> adet. {@code reportCount}: acik varsa acik sayisi, yoksa toplam.
     */
    public record ReportItem(Long id, String targetType, Long targetId, Long topicId, String status, List<String> reasons,
                             Map<String, Long> reasonCounts, String note, long reportCount, long openReports,
                             long totalReports, Long resolveReportId, CategoryRef category, ReportPreview preview,
                             String createdAt, String firstReportedAt, String lastReportedAt) {}

    /**
     * Moderasyon islem kaydi. {@code targetType}: FORUM_TOPIC | FORUM_COMMENT. {@code actor} (+ duz {@code actorId},
     * {@code actorName}): islemi yapan yonetici; otomatik gizlemede ve Basic auth yoneticisinde null.
     */
    public record ActionItem(Long id, String targetType, Long targetId, Long topicId, String action, String reason,
                             String source, Long actorId, String actorName, AuthorRef actor, String createdAt) {}

    /**
     * Konu listesi satiri (yonetici). {@code status}: ACTIVE | REMOVED | DELETED (sahibi sildi); {@code categoryId} /
     * {@code categoryName} {@code category} ile ayni bilgi (duz alan kolayligi).
     */
    public record TopicItem(Long id, String title, String bodyPreview, Long categoryId, String categoryName,
                            CategoryRef category, String status, boolean pinned, boolean locked, boolean anonymous,
                            AuthorRef author, long commentCount, long likeCount, long openReportCount, String removedReason,
                            String createdAt, String lastActivityAt) {}
}
