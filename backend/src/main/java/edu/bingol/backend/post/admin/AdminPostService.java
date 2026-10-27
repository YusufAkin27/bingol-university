package edu.bingol.backend.post.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.comment.PostCommentService;
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
 * Yonetici gonderi/yorum moderasyonu (Kesfet akisi). Duz SQL: A'nin Post depolarina bagimlilik yok; sema
 * docs/POSTS_DESIGN.md'deki V310 tablolarindan. Yonetici icin gorunurluk kisiti yoktur (gizli/silinmis dahil).
 * Gizleme geri alinabilir (post.hidden_at); silme yumusaktir (deleted_at) ve PostDeletedEvent yayinlar
 * (medya dosyalari 30 gun sonra temizlenir). Yazma islemleri AuditInterceptor ile denetlenir.
 */
@Service
public class AdminPostService {

    public static final int MAX_PAGE = 50;
    public static final String MEDIA_URL = "/api/admin/posts/media/";
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    public record Author(long id, String displayName, String email, String avatarUrl) {}

    public record MediaItem(long id, String kind, String url, String thumbUrl, Integer width, Integer height,
                            Integer durationMs, boolean hidden) {}

    public record PostRow(long id, Author author, String text, List<MediaItem> media, int likeCount, int commentCount,
                          int mediaCount, boolean hidden, boolean deleted, String hiddenReason, String createdAt,
                          String editedAt, String hiddenAt, String deletedAt, Long deletedBy) {}

    public record CommentRow(long id, long postId, Long parentId, Long rootId, int depth, Author author,
                             Long replyToUserId, String text, int replyCount, boolean hidden, boolean deleted,
                             String createdAt, String deletedAt) {}

    public record PostPage(List<PostRow> items, Long nextCursor) {}

    public record CommentPage(List<CommentRow> items, Long nextCursor) {}

    public record PostDetail(PostRow post, CommentPage comments) {}

    public record Counts(long postCount, long commentCount, long likeCount, long mediaCount, long hiddenCount,
                         long deletedCount) {}

    public record Stats(long postCount, long commentCount, long likeCount, long mediaCount, long hiddenCount,
                        long deletedCount, Counts last24h) {}

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;
    private final PostMediaService media;
    private final PostService posts;
    private final PostCommentService commentService;

    public AdminPostService(JdbcTemplate jdbc, PostMediaService media, PostService posts,
                            PostCommentService commentService) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
        this.media = media;
        this.posts = posts;
        this.commentService = commentService;
    }

    // --- okuma ---

    @Transactional(readOnly = true)
    public PostPage list(Long cursor, int size, String q, Boolean hidden, Boolean deleted, Boolean hasMedia,
                         String from, String to) {
        int n = clamp(size);
        StringBuilder sql = new StringBuilder(POST_SELECT).append(" WHERE 1 = 1");
        MapSqlParameterSource p = new MapSqlParameterSource();
        if (cursor != null) {
            sql.append(" AND p.id < :cursor");
            p.addValue("cursor", cursor);
        }
        if (q != null && !q.isBlank()) {
            String like = likePattern(q.trim());
            sql.append(" AND (u.display_name ILIKE :like OR u.email ILIKE :like)");
            p.addValue("like", like);
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
        return new PostDetail(row, comments(postId, null, 30));
    }

    /** Gonderinin TUM yorumlari (silinmis/gizli dahil), eskiden yeniye; imlec = yorum id. */
    @Transactional(readOnly = true)
    public CommentPage comments(long postId, Long cursor, int size) {
        requirePost(postId);
        int n = clamp(size);
        List<CommentRow> rows = jdbc.query(COMMENT_SELECT + " WHERE c.post_id = ? AND c.id > ? ORDER BY c.id ASC LIMIT ?",
                (rs, i) -> commentRow(rs), postId, cursor == null ? 0L : cursor, n + 1);
        boolean more = rows.size() > n;
        List<CommentRow> page = more ? rows.subList(0, n) : rows;
        return new CommentPage(page, more ? page.get(page.size() - 1).id() : null);
    }

    @Transactional(readOnly = true)
    public Stats stats() {
        Counts all = counts(null);
        Counts day = counts(Timestamp.from(Instant.now().minusSeconds(86400)));
        return new Stats(all.postCount(), all.commentCount(), all.likeCount(), all.mediaCount(), all.hiddenCount(),
                all.deletedCount(), day);
    }

    private Counts counts(Timestamp since) {
        String w = since == null ? "" : " AND created_at >= ?";
        Object[] a = since == null ? new Object[0] : new Object[] {since};
        long posts = num("SELECT COUNT(*) FROM post WHERE deleted_at IS NULL" + w, a);
        long comments = num("SELECT COUNT(*) FROM post_comment WHERE deleted_at IS NULL" + w, a);
        long likes = num("SELECT COUNT(*) FROM post_like WHERE 1 = 1" + w, a);
        long mediaCount = num("SELECT COUNT(*) FROM post_media WHERE post_id IS NOT NULL" + w, a);
        long hiddenCount = num("SELECT COUNT(*) FROM post WHERE hidden_at IS NOT NULL AND deleted_at IS NULL" + w, a);
        long deletedCount = num("SELECT COUNT(*) FROM post WHERE deleted_at IS NOT NULL" + w, a);
        return new Counts(posts, comments, likes, mediaCount, hiddenCount, deletedCount);
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

    /** Yumusak silme (PostService.delete ADMIN: PostDeletedEvent ile medya temizligi). Silinmisse 404. */
    @Transactional
    public void delete(long adminId, long postId) {
        posts.delete(adminId, postId, true);
    }

    @Transactional
    public CommentRow hideComment(long commentId) {
        requireComment(commentId);
        jdbc.update("UPDATE post_comment SET hidden_at = CURRENT_TIMESTAMP WHERE id = ? AND hidden_at IS NULL", commentId);
        return comment(commentId);
    }

    @Transactional
    public CommentRow unhideComment(long commentId) {
        requireComment(commentId);
        jdbc.update("UPDATE post_comment SET hidden_at = NULL WHERE id = ?", commentId);
        return comment(commentId);
    }

    /** Yorumu sil (PostCommentService semantigi: yanitlisa "silindi" kaydi kalir; sayaclar duser). */
    @Transactional
    public void deleteComment(long adminId, long commentId) {
        requireComment(commentId);
        commentService.delete(adminId, commentId, true);
    }

    // --- yardimcilar ---

    private static final String POST_SELECT = "SELECT p.id, p.author_id, u.display_name, u.email, u.avatar_url, p.body, "
            + "p.like_count, p.comment_count, p.media_count, p.created_at, p.edited_at, p.deleted_at, p.deleted_by, "
            + "p.hidden_at, p.hidden_reason FROM post p JOIN app_user u ON u.id = p.author_id";

    private static final String COMMENT_SELECT = "SELECT c.id, c.post_id, c.parent_id, c.root_id, c.depth, c.author_id, "
            + "u.display_name, u.email, u.avatar_url, c.reply_to_user_id, c.body, c.reply_count, c.created_at, "
            + "c.deleted_at, c.hidden_at FROM post_comment c JOIN app_user u ON u.id = c.author_id";

    private PostRow postRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        Author a = new Author(rs.getLong("author_id"), rs.getString("display_name"), rs.getString("email"),
                rs.getString("avatar_url"));
        return new PostRow(rs.getLong("id"), a, rs.getString("body"), List.of(), rs.getInt("like_count"),
                rs.getInt("comment_count"), rs.getInt("media_count"), rs.getTimestamp("hidden_at") != null,
                rs.getTimestamp("deleted_at") != null, rs.getString("hidden_reason"), ts(rs.getTimestamp("created_at")),
                ts(rs.getTimestamp("edited_at")), ts(rs.getTimestamp("hidden_at")), ts(rs.getTimestamp("deleted_at")),
                (Long) rs.getObject("deleted_by"));
    }

    private CommentRow commentRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        Author a = new Author(rs.getLong("author_id"), rs.getString("display_name"), rs.getString("email"),
                rs.getString("avatar_url"));
        return new CommentRow(rs.getLong("id"), rs.getLong("post_id"), (Long) rs.getObject("parent_id"),
                (Long) rs.getObject("root_id"), rs.getInt("depth"), a, (Long) rs.getObject("reply_to_user_id"),
                rs.getString("body"), rs.getInt("reply_count"), rs.getTimestamp("hidden_at") != null,
                rs.getTimestamp("deleted_at") != null, ts(rs.getTimestamp("created_at")), ts(rs.getTimestamp("deleted_at")));
    }

    private PostRow one(long postId) {
        List<PostRow> rows = jdbc.query(POST_SELECT + " WHERE p.id = ?", (rs, i) -> postRow(rs), postId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
        }
        return withMedia(rows).get(0);
    }

    private CommentRow comment(long commentId) {
        List<CommentRow> rows = jdbc.query(COMMENT_SELECT + " WHERE c.id = ?", (rs, i) -> commentRow(rs), commentId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMENT_NOT_FOUND", "Yorum bulunamadı.");
        }
        return rows.get(0);
    }

    private void requirePost(long postId) {
        if (num("SELECT COUNT(*) FROM post WHERE id = ?", postId) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
        }
    }

    private void requireComment(long commentId) {
        if (num("SELECT COUNT(*) FROM post_comment WHERE id = ?", commentId) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMENT_NOT_FOUND", "Yorum bulunamadı.");
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
                    r.commentCount(), r.mediaCount(), r.hidden(), r.deleted(), r.hiddenReason(), r.createdAt(),
                    r.editedAt(), r.hiddenAt(), r.deletedAt(), r.deletedBy()));
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
