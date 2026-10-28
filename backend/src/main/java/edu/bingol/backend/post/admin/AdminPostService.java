package edu.bingol.backend.post.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.moderation.ModerationNotifier;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.post.media.PostMediaService;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici gonderi moderasyonu (Kesfet akisi). Duz SQL: A'nin Post depolarina bagimlilik yok; sema
 * docs/POSTS_DESIGN.md'deki V310 tablolarindan. Yonetici icin gorunurluk kisiti yoktur (gizli/silinmis dahil).
 * Gizleme geri alinabilir (post.hidden_at); silme yumusaktir (deleted_at) ve PostDeletedEvent yayinlar
 * (medya dosyalari 30 gun sonra temizlenir). Yazma islemleri AuditInterceptor ile denetlenir.
 * Metin duzenleme: yonetici icin ContentGuard (kufur suzgeci) ATLANIR (yonetici ihlalli metni temizlemek icin
 * duzenler; islem denetim kaydina yazilir), ancak gonderi bicim kurali (tek satir, 7 kelime/60 karakter) uygulanir.
 * Silmede acik FEED_POST raporlari ReportService.resolve(HIDE) ile sonuclandirilir (yazara ve raporlayanlara
 * bildirim, ihlal kaydi oradan); rapor yoksa yazara dogrudan "kaldirildi" bildirimi gider.
 */
@Service
public class AdminPostService {

    public static final int MAX_PAGE = 50;
    public static final String MEDIA_URL = "/api/admin/posts/media/";
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    public record Author(long id, String displayName, String email, String avatarUrl) {}

    public record MediaItem(long id, String kind, String url, String thumbUrl, Integer width, Integer height,
                            Integer durationMs, boolean hidden) {}

    public record PostRow(long id, Author author, String text, List<MediaItem> media, int likeCount, int mediaCount,
                          boolean hidden, boolean deleted, String hiddenReason, String createdAt, String editedAt,
                          String hiddenAt, String deletedAt, Long deletedBy, int openReportCount) {}

    public record ReportItem(long id, String reason, String note, String status, String createdAt) {}

    public record PostPage(List<PostRow> items, Long nextCursor) {}

    /** Detay: gonderi + bu gonderiye yapilan tum sikayetler (acik olanlar once). */
    public record PostDetail(PostRow post, List<ReportItem> reports) {}

    public record Counts(long postCount, long likeCount, long mediaCount, long hiddenCount, long deletedCount) {}

    public record Stats(long postCount, long likeCount, long mediaCount, long hiddenCount, long deletedCount,
                        long openReportedCount, Counts last24h) {}

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;
    private final PostMediaService media;
    private final PostService posts;
    private final ReportService reports;
    private final ModerationNotifier moderationNotifier;
    private final NotificationService notifications;

    public AdminPostService(JdbcTemplate jdbc, PostMediaService media, PostService posts, ReportService reports,
                            ModerationNotifier moderationNotifier, NotificationService notifications) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
        this.media = media;
        this.posts = posts;
        this.reports = reports;
        this.moderationNotifier = moderationNotifier;
        this.notifications = notifications;
    }

    // --- okuma ---

    @Transactional(readOnly = true)
    public PostPage list(Long cursor, int size, String q, Boolean hidden, Boolean deleted, Boolean hasMedia,
                         String from, String to, String status, Long authorId, Integer minReports) {
        int n = clamp(size);
        StringBuilder sql = new StringBuilder(POST_SELECT).append(" WHERE 1 = 1");
        MapSqlParameterSource p = new MapSqlParameterSource();
        if (cursor != null) {
            sql.append(" AND p.id < :cursor");
            p.addValue("cursor", cursor);
        }
        if (q != null && !q.isBlank()) {
            String like = likePattern(q.trim());
            sql.append(" AND (p.body ILIKE :like OR u.display_name ILIKE :like OR u.email ILIKE :like)");
            p.addValue("like", like);
        }
        if (authorId != null) {
            sql.append(" AND p.author_id = :author");
            p.addValue("author", authorId);
        }
        if (minReports != null && minReports > 0) {
            sql.append(" AND (").append(OPEN_REPORTS).append(") >= :minReports");
            p.addValue("minReports", minReports);
        }
        String st = status == null ? "" : status.trim().toUpperCase(java.util.Locale.ROOT);
        switch (st) {
            case "", "ALL" -> { }
            case "VISIBLE" -> sql.append(" AND p.deleted_at IS NULL AND p.hidden_at IS NULL");
            case "HIDDEN" -> sql.append(" AND p.deleted_at IS NULL AND p.hidden_at IS NOT NULL");
            case "DELETED" -> sql.append(" AND p.deleted_at IS NOT NULL");
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz durum süzgeci.");
        }
        if (hidden != null) {
            sql.append(hidden ? " AND p.hidden_at IS NOT NULL" : " AND p.hidden_at IS NULL");
        }
        if (deleted != null) {
            sql.append(deleted ? " AND p.deleted_at IS NOT NULL" : " AND p.deleted_at IS NULL");
        }
        if (hasMedia != null) {
            sql.append(hasMedia ? " AND p.media_count > 0" : " AND p.media_count = 0");
        }
        Instant f = day(from, false);
        if (f != null) {
            sql.append(" AND p.created_at >= :from");
            p.addValue("from", Timestamp.from(f));
        }
        Instant t = day(to, true);
        if (t != null) {
            sql.append(" AND p.created_at < :to");
            p.addValue("to", Timestamp.from(t));
        }
        sql.append(" ORDER BY p.id DESC LIMIT :lim");
        p.addValue("lim", n + 1);
        List<PostRow> rows = named.query(sql.toString(), p, (rs, i) -> postRow(rs));
        boolean more = rows.size() > n;
        List<PostRow> page = new ArrayList<>(more ? rows.subList(0, n) : rows);
        return new PostPage(withMedia(page), more ? page.get(page.size() - 1).id() : null);
    }

    @Transactional(readOnly = true)
    public PostDetail detail(long postId) {
        PostRow row = one(postId);
        List<ReportItem> items = jdbc.query("SELECT id, reason, note, status, created_at FROM report "
                + "WHERE target_type = 'FEED_POST' AND target_id = ? "
                + "ORDER BY CASE WHEN status = 'OPEN' THEN 0 ELSE 1 END, id DESC LIMIT 50",
                (rs, i) -> new ReportItem(rs.getLong("id"), rs.getString("reason"), rs.getString("note"),
                        rs.getString("status"), ts(rs.getTimestamp("created_at"))), postId);
        return new PostDetail(row, items);
    }

    @Transactional(readOnly = true)
    public Stats stats() {
        Counts all = counts(null);
        Counts day = counts(Timestamp.from(Instant.now().minusSeconds(86400)));
        long reported = num("SELECT COUNT(DISTINCT target_id) FROM report WHERE target_type = 'FEED_POST' AND status = 'OPEN'");
        return new Stats(all.postCount(), all.likeCount(), all.mediaCount(), all.hiddenCount(), all.deletedCount(),
                reported, day);
    }

    private Counts counts(Timestamp since) {
        String w = since == null ? "" : " AND created_at >= ?";
        Object[] a = since == null ? new Object[0] : new Object[] {since};
        long posts = num("SELECT COUNT(*) FROM post WHERE deleted_at IS NULL" + w, a);
        long likes = num("SELECT COUNT(*) FROM post_like WHERE 1 = 1" + w, a);
        long mediaCount = num("SELECT COUNT(*) FROM post_media WHERE post_id IS NOT NULL" + w, a);
        long hiddenCount = num("SELECT COUNT(*) FROM post WHERE hidden_at IS NOT NULL AND deleted_at IS NULL" + w, a);
        long deletedCount = num("SELECT COUNT(*) FROM post WHERE deleted_at IS NOT NULL" + w, a);
        return new Counts(posts, likes, mediaCount, hiddenCount, deletedCount);
    }

    // --- yazma ---

    /** Gonderiyi gizle (geri alinabilir). Idempotent. */
    @Transactional
    public PostRow hide(long postId, String reason) {
        requirePost(postId);
        jdbc.update("UPDATE post SET hidden_at = CURRENT_TIMESTAMP, hidden_reason = ? WHERE id = ? AND hidden_at IS NULL",
                trim(reason, 300), postId);
        media.hide(postId);
        return one(postId);
    }

    @Transactional
    public PostRow unhide(long postId) {
        requirePost(postId);
        jdbc.update("UPDATE post SET hidden_at = NULL, hidden_reason = NULL WHERE id = ?", postId);
        media.unhide(postId);
        return one(postId);
    }

    /**
     * Metni duzenle (yonetici). Bos/bosluk = metin temizlenir (fotograf kalir). ContentGuard atlanir (sinif notu);
     * silinmis gonderi 404. Yazara yerellestirilmis bildirim gider.
     */
    @Transactional
    public PostRow editText(long postId, String text) {
        Long authorId = posts.adminEdit(postId, text);
        notifyEdited(authorId, postId);
        return one(postId);
    }

    /**
     * Yumusak silme (PostService.delete ADMIN: PostDeletedEvent ile medya temizligi). Silinmisse 404. Gonderinin acik
     * raporlari varsa once ReportService.resolve(HIDE) ile sonuclandirilir (yazar + raporlayanlar bilgilendirilir);
     * yoksa yazara dogrudan "kaldirildi" bildirimi gider. reason: yazara giden gerekce (bos olabilir).
     */
    @Transactional
    public void delete(long adminId, long postId, String reason) {
        List<Long> owner = jdbc.queryForList("SELECT author_id FROM post WHERE id = ? AND deleted_at IS NULL", Long.class,
                postId);
        if (owner.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
        }
        Long authorId = owner.get(0);
        String why = trim(reason, 300);
        List<Long> open = jdbc.queryForList("SELECT id FROM report WHERE target_type = 'FEED_POST' AND target_id = ? "
                + "AND status = 'OPEN' ORDER BY id LIMIT 1", Long.class, postId);
        if (!open.isEmpty()) {
            reports.resolve(open.get(0), adminId, Report.Resolution.HIDE, why, null);
        } else if (authorId != null) {
            moderationNotifier.removed(authorId, ReportTargetType.FEED_POST, postId, why);
        }
        posts.delete(adminId, postId, true);
        if (why != null) {
            jdbc.update("UPDATE post SET hidden_reason = ? WHERE id = ?", why, postId); // yonetici gerekcesi (denetim)
        }
    }

    // --- yardimcilar ---

    private static final String OPEN_REPORTS = "SELECT COUNT(*) FROM report r WHERE r.target_type = 'FEED_POST' "
            + "AND r.target_id = p.id AND r.status = 'OPEN'";

    private static final String POST_SELECT = "SELECT p.id, p.author_id, u.display_name, u.email, u.avatar_url, p.body, "
            + "p.like_count, p.media_count, p.created_at, p.edited_at, p.deleted_at, p.deleted_by, "
            + "p.hidden_at, p.hidden_reason, (" + OPEN_REPORTS + ") AS open_reports "
            + "FROM post p JOIN app_user u ON u.id = p.author_id";

    private PostRow postRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        Author a = new Author(rs.getLong("author_id"), rs.getString("display_name"), rs.getString("email"),
                rs.getString("avatar_url"));
        return new PostRow(rs.getLong("id"), a, rs.getString("body"), List.of(), rs.getInt("like_count"),
                rs.getInt("media_count"), rs.getTimestamp("hidden_at") != null,
                rs.getTimestamp("deleted_at") != null, rs.getString("hidden_reason"), ts(rs.getTimestamp("created_at")),
                ts(rs.getTimestamp("edited_at")), ts(rs.getTimestamp("hidden_at")), ts(rs.getTimestamp("deleted_at")),
                (Long) rs.getObject("deleted_by"), rs.getInt("open_reports"));
    }

    private PostRow one(long postId) {
        List<PostRow> rows = jdbc.query(POST_SELECT + " WHERE p.id = ?", (rs, i) -> postRow(rs), postId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
        }
        return withMedia(rows).get(0);
    }

    private void requirePost(long postId) {
        if (num("SELECT COUNT(*) FROM post WHERE id = ?", postId) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
        }
    }

    /** Gonderi satirlarina medya (yonetici uclari) ekler; tek sorgu. */
    private List<PostRow> withMedia(List<PostRow> rows) {
        if (rows.isEmpty()) {
            return rows;
        }
        List<Long> ids = rows.stream().map(PostRow::id).toList();
        Map<Long, List<MediaItem>> byPost = new HashMap<>();
        named.query("SELECT id, post_id, kind, width, height, duration_ms, hidden_at FROM post_media "
                        + "WHERE post_id IN (:ids) ORDER BY post_id, position, id",
                new MapSqlParameterSource("ids", ids), rs -> {
                    long id = rs.getLong("id");
                    byPost.computeIfAbsent(rs.getLong("post_id"), k -> new ArrayList<>()).add(new MediaItem(id,
                            rs.getString("kind"), MEDIA_URL + id, MEDIA_URL + id + "?thumb=true",
                            (Integer) rs.getObject("width"), (Integer) rs.getObject("height"),
                            (Integer) rs.getObject("duration_ms"), rs.getTimestamp("hidden_at") != null));
                });
        List<PostRow> out = new ArrayList<>();
        for (PostRow r : rows) {
            out.add(new PostRow(r.id(), r.author(), r.text(), byPost.getOrDefault(r.id(), List.of()), r.likeCount(),
                    r.mediaCount(), r.hidden(), r.deleted(), r.hiddenReason(), r.createdAt(), r.editedAt(),
                    r.hiddenAt(), r.deletedAt(), r.deletedBy(), r.openReportCount()));
        }
        return out;
    }

    private long num(String sql, Object... args) {
        Long v = jdbc.queryForObject(sql, Long.class, args);
        return v == null ? 0 : v;
    }

    static int clamp(int size) {
        return Math.min(Math.max(size, 1), MAX_PAGE);
    }

    static String likePattern(String q) {
        return "%" + q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
    }

    private void notifyEdited(Long authorId, long postId) {
        if (authorId == null) {
            return;
        }
        notifications.sendTemplated(authorId, NotificationType.SYSTEM, "notif.post.adminedit",
                java.util.Map.of("targetType", "FEED_POST", "targetId", String.valueOf(postId)));
    }

    private static String trim(String s, int max) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String t = s.trim();
        return t.length() <= max ? t : t.substring(0, max);
    }

    private static String ts(Timestamp t) {
        return t == null ? null : t.toInstant().toString();
    }

    private static Instant day(String s, boolean endExclusive) {
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            LocalDate d = LocalDate.parse(s.trim());
            return (endExclusive ? d.plusDays(1) : d).atStartOfDay(ZONE).toInstant();
        } catch (DateTimeParseException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz tarih (YYYY-AA-GG bekleniyor).");
        }
    }
}
