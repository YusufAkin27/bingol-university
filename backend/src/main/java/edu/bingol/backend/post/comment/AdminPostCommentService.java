package edu.bingol.backend.post.comment;

import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.ModerationNotifier;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetType;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici yorum moderasyonu (KS-BE2). Duz SQL; yonetici icin gorunurluk kisiti yoktur (gizli/silinmis dahil). Gizleme
 * geri alinabilir (hidden_at); silme yumusaktir ve ust duzey yorumda yanitlari da kaldirir. Yazma islemleri
 * AuditInterceptor ile denetlenir. Silmede acik COMMENT raporu varsa ReportService.resolve(HIDE) ile sonuclandirilir
 * (yazara + raporlayanlara bildirim, ihlal kaydi); yoksa yazara dogrudan "kaldirildi" bildirimi gider.
 */
@Service
public class AdminPostCommentService {

    public static final int MAX_PAGE = 50;

    public record Author(long id, String displayName, String email, String avatarUrl) {}

    public record Row(long id, long postId, Long parentId, Long replyToId, Author author, String text, int likeCount,
                      int replyCount, boolean hidden, boolean deleted, String hiddenReason, String createdAt,
                      String hiddenAt, String deletedAt, Long deletedBy, int openReportCount) {}

    public record Page(List<Row> items, Long nextCursor) {}

    private static final String SELECT = "SELECT c.id, c.post_id, c.parent_id, c.reply_to_id, c.author_id, u.display_name, "
            + "u.email, u.avatar_url, c.body, c.like_count, c.reply_count, c.created_at, c.hidden_at, c.hidden_reason, "
            + "c.deleted_at, c.deleted_by, (SELECT COUNT(*) FROM report r WHERE r.target_type = 'COMMENT' "
            + "AND r.target_id = c.id AND r.status = 'OPEN') AS open_reports "
            + "FROM post_comment c JOIN app_user u ON u.id = c.author_id";

    private final JdbcTemplate jdbc;
    private final PostCommentService comments;
    private final CommentCounters counters;
    private final ReportService reports;
    private final ModerationNotifier moderationNotifier;

    public AdminPostCommentService(JdbcTemplate jdbc, PostCommentService comments, CommentCounters counters,
                                   ReportService reports, ModerationNotifier moderationNotifier) {
        this.jdbc = jdbc;
        this.comments = comments;
        this.counters = counters;
        this.reports = reports;
        this.moderationNotifier = moderationNotifier;
    }

    /** Bir gonderinin tum yorum/yanitlari (en yeni once, imlec = yorum id). status = ALL|VISIBLE|HIDDEN|DELETED. */
    @Transactional(readOnly = true)
    public Page list(long postId, Long cursor, int size, String status) {
        if (num("SELECT COUNT(*) FROM post WHERE id = ?", postId) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
        }
        int n = Math.min(Math.max(size, 1), MAX_PAGE);
        StringBuilder sql = new StringBuilder(SELECT).append(" WHERE c.post_id = ?");
        List<Object> args = new ArrayList<>();
        args.add(postId);
        if (cursor != null) {
            sql.append(" AND c.id < ?");
            args.add(cursor);
        }
        String st = status == null ? "" : status.trim().toUpperCase(Locale.ROOT);
        switch (st) {
            case "", "ALL" -> { }
            case "VISIBLE" -> sql.append(" AND c.deleted_at IS NULL AND c.hidden_at IS NULL");
            case "HIDDEN" -> sql.append(" AND c.deleted_at IS NULL AND c.hidden_at IS NOT NULL");
            case "DELETED" -> sql.append(" AND c.deleted_at IS NOT NULL");
            default -> throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz durum süzgeci.");
        }
        sql.append(" ORDER BY c.id DESC LIMIT ?");
        args.add(n + 1);
        List<Row> rows = jdbc.query(sql.toString(), (rs, i) -> row(rs), args.toArray());
        boolean more = rows.size() > n;
        List<Row> page = more ? rows.subList(0, n) : rows;
        return new Page(page, more ? page.get(page.size() - 1).id() : null);
    }

    /** Yorumu gizle (geri alinabilir; idempotent). */
    @Transactional
    public Row hide(long commentId, String reason) {
        requireComment(commentId);
        jdbc.update("UPDATE post_comment SET hidden_at = CURRENT_TIMESTAMP, hidden_reason = ? WHERE id = ? "
                + "AND hidden_at IS NULL AND deleted_at IS NULL", trim(reason, 300), commentId);
        recount(commentId);
        return one(commentId);
    }

    @Transactional
    public Row unhide(long commentId) {
        requireComment(commentId);
        jdbc.update("UPDATE post_comment SET hidden_at = NULL, hidden_reason = NULL WHERE id = ? AND deleted_at IS NULL", commentId);
        recount(commentId);
        return one(commentId);
    }

    /** Silme (yumusak). reason: yazara giden gerekce (bos olabilir). Silinmisse 404. */
    @Transactional
    public void delete(long adminId, long commentId, String reason) {
        List<Long> owner = jdbc.queryForList("SELECT author_id FROM post_comment WHERE id = ? AND deleted_at IS NULL",
                Long.class, commentId);
        if (owner.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMENT_NOT_FOUND", "Yorum bulunamadı.");
        }
        String why = trim(reason, 300);
        List<Long> open = jdbc.queryForList("SELECT id FROM report WHERE target_type = 'COMMENT' AND target_id = ? "
                + "AND status = 'OPEN' ORDER BY id LIMIT 1", Long.class, commentId);
        if (!open.isEmpty()) {
            reports.resolve(open.get(0), adminId, Report.Resolution.HIDE, why, null);
        } else {
            moderationNotifier.removed(owner.get(0), ReportTargetType.COMMENT, commentId, why);
        }
        comments.delete(adminId, commentId, true);
        if (why != null) {
            jdbc.update("UPDATE post_comment SET hidden_reason = ? WHERE id = ?", why, commentId); // gerekce (denetim)
        }
    }

    // --- yardimcilar ---

    private Row row(java.sql.ResultSet rs) throws java.sql.SQLException {
        Author a = new Author(rs.getLong("author_id"), rs.getString("display_name"),
                PermissionAwareMasking.email(rs.getString("email")), rs.getString("avatar_url"));
        return new Row(rs.getLong("id"), rs.getLong("post_id"), (Long) rs.getObject("parent_id"),
                (Long) rs.getObject("reply_to_id"), a, rs.getString("body"), rs.getInt("like_count"),
                rs.getInt("reply_count"), rs.getTimestamp("hidden_at") != null, rs.getTimestamp("deleted_at") != null,
                rs.getString("hidden_reason"), ts(rs.getTimestamp("created_at")), ts(rs.getTimestamp("hidden_at")),
                ts(rs.getTimestamp("deleted_at")), (Long) rs.getObject("deleted_by"), rs.getInt("open_reports"));
    }

    private Row one(long commentId) {
        List<Row> rows = jdbc.query(SELECT + " WHERE c.id = ?", (rs, i) -> row(rs), commentId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMENT_NOT_FOUND", "Yorum bulunamadı.");
        }
        return rows.get(0);
    }

    private void requireComment(long commentId) {
        if (num("SELECT COUNT(*) FROM post_comment WHERE id = ?", commentId) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMENT_NOT_FOUND", "Yorum bulunamadı.");
        }
    }

    private void recount(long commentId) {
        counters.recountPosts(jdbc.queryForList("SELECT post_id FROM post_comment WHERE id = ?", Long.class, commentId));
    }

    private long num(String sql, Object... args) {
        Long v = jdbc.queryForObject(sql, Long.class, args);
        return v == null ? 0 : v;
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
}
