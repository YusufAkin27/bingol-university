package edu.bingol.backend.forum.profile;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Profil / etkinlik listeleri icin kimlik secimi (duz SQL, PostgreSQL ve H2'de calisir). Imlec anahtar kumesidir:
 * (zaman, kimlik) azalan. Burada YALNIZ sahiplik/durum suzgeci vardir; bakana gore gorunurluk (engel, sessize alma,
 * gizli hesap) {@link ForumProfileService} + A'nin ozet SPI'sindedir. Kimlikli sorgular her zaman LIMIT'lidir.
 *
 * <p>ANONIMLIK: {@code includeAnonymous=false} (baskasinin profili) iken anonim konu/yorum VE anonim konunun
 * yazarinin o konuya ADIYLA yazdigi yorum disarida kalir (yorumun adiyla gorunmesi o konunun yazari oldugunu ifsa eder).
 */
@Repository
public class ForumProfileRepository {

    /** Konu/yorum satiri: sirali kimlik + imlec zamani. */
    public record Row(long id, Instant at) {}

    /** Yorum satiri: yorum + bagli konu. */
    public record CommentRow(long id, long topicId, String topicTitle, Instant at) {}

    /** Kaydedilen oge. */
    public record SavedRow(String type, long targetId, Instant at) {}

    /** Yorumun bagli konusu (kaydedilenler listesinde baslik gostermek icin). */
    public record CommentContext(long topicId, String title) {}

    /** Imlec noktasi (null = ilk sayfa). */
    public record Cursor(Instant at, long id) {}

    private final JdbcTemplate jdbc;

    public ForumProfileRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Row> topics(long ownerId, boolean includeAnonymous, Cursor cur, int limit) {
        StringBuilder sql = new StringBuilder("""
                SELECT t.id, t.created_at FROM forum_topic t
                 WHERE t.user_id = ? AND t.deleted_at IS NULL AND t.status = 'ACTIVE'""");
        List<Object> args = new ArrayList<>(List.of(ownerId));
        if (!includeAnonymous) {
            sql.append(" AND t.anonymous = FALSE");
        }
        keyset(sql, args, "t.created_at", "t.id", cur);
        sql.append(" ORDER BY t.created_at DESC, t.id DESC LIMIT ?");
        args.add(limit);
        return jdbc.query(sql.toString(), (rs, i) -> new Row(rs.getLong(1), rs.getTimestamp(2).toInstant()), args.toArray());
    }

    public List<CommentRow> comments(long ownerId, boolean includeAnonymous, Cursor cur, int limit) {
        StringBuilder sql = new StringBuilder("""
                SELECT c.id, c.topic_id, t.title, c.created_at
                  FROM forum_comment c JOIN forum_topic t ON t.id = c.topic_id
                 WHERE c.user_id = ? AND c.deleted_at IS NULL AND c.status = 'ACTIVE'
                   AND t.deleted_at IS NULL AND t.status = 'ACTIVE'""");
        List<Object> args = new ArrayList<>(List.of(ownerId));
        if (!includeAnonymous) {
            sql.append(" AND c.anonymous = FALSE AND NOT (t.anonymous = TRUE AND t.user_id = c.user_id)");
        }
        keyset(sql, args, "c.created_at", "c.id", cur);
        sql.append(" ORDER BY c.created_at DESC, c.id DESC LIMIT ?");
        args.add(limit);
        return jdbc.query(sql.toString(), (rs, i) -> new CommentRow(rs.getLong(1), rs.getLong(2), rs.getString(3),
                rs.getTimestamp(4).toInstant()), args.toArray());
    }

    /** Takip ettigim konular (follow=TRUE), son takip edilen once; imlec takip zamani + konu kimligi. */
    public List<Row> following(long userId, Cursor cur, int limit) {
        StringBuilder sql = new StringBuilder("""
                SELECT t.id, f.created_at FROM forum_topic_follow f JOIN forum_topic t ON t.id = f.topic_id
                 WHERE f.user_id = ? AND f.follow = TRUE AND t.deleted_at IS NULL AND t.status = 'ACTIVE'""");
        List<Object> args = new ArrayList<>(List.of(userId));
        keyset(sql, args, "f.created_at", "t.id", cur);
        sql.append(" ORDER BY f.created_at DESC, t.id DESC LIMIT ?");
        args.add(limit);
        return jdbc.query(sql.toString(), (rs, i) -> new Row(rs.getLong(1), rs.getTimestamp(2).toInstant()), args.toArray());
    }

    /** Kaydedilenler (konu + yorum karisik), son kaydedilen once; imlec kayit zamani + hedef kimligi. */
    public List<SavedRow> saved(long userId, Cursor cur, int limit) {
        StringBuilder sql = new StringBuilder("SELECT b.target_type, b.target_id, b.created_at FROM forum_bookmark b "
                + "WHERE b.user_id = ?");
        List<Object> args = new ArrayList<>(List.of(userId));
        keyset(sql, args, "b.created_at", "b.target_id", cur);
        sql.append(" ORDER BY b.created_at DESC, b.target_id DESC, b.target_type DESC LIMIT ?");
        args.add(limit);
        return jdbc.query(sql.toString(), (rs, i) -> new SavedRow(rs.getString(1), rs.getLong(2),
                rs.getTimestamp(3).toInstant()), args.toArray());
    }

    /** Yorum kimliklerinin bagli (gorunur) konusu: kimlik -> (konu, baslik). Konusu silinmis/kaldirilmis yorum yoktur. */
    public java.util.Map<Long, CommentContext> commentContext(java.util.Collection<Long> commentIds) {
        java.util.Map<Long, CommentContext> out = new java.util.HashMap<>();
        if (commentIds.isEmpty()) {
            return out;
        }
        String in = String.join(",", java.util.Collections.nCopies(commentIds.size(), "?"));
        jdbc.query("SELECT c.id, t.id, t.title FROM forum_comment c JOIN forum_topic t ON t.id = c.topic_id "
                + "WHERE c.id IN (" + in + ") AND t.deleted_at IS NULL AND t.status = 'ACTIVE'",
                rs -> {
                    out.put(rs.getLong(1), new CommentContext(rs.getLong(2), rs.getString(3)));
                }, commentIds.toArray());
        return out;
    }

    /** Anonimsiz sayilar (baskasinin profili): gorunen konu sayisi. */
    public long publicTopicCount(long ownerId) {
        Long n = jdbc.queryForObject("""
                SELECT COUNT(*) FROM forum_topic WHERE user_id = ? AND anonymous = FALSE AND deleted_at IS NULL
                   AND status = 'ACTIVE'""", Long.class, ownerId);
        return n == null ? 0 : n;
    }

    /** Anonimsiz sayilar (baskasinin profili): gorunen yorum sayisi (anonim konu yazarinin adli yorumu sayilmaz). */
    public long publicCommentCount(long ownerId) {
        Long n = jdbc.queryForObject("""
                SELECT COUNT(*) FROM forum_comment c JOIN forum_topic t ON t.id = c.topic_id
                 WHERE c.user_id = ? AND c.anonymous = FALSE AND c.deleted_at IS NULL AND c.status = 'ACTIVE'
                   AND t.deleted_at IS NULL AND t.status = 'ACTIVE' AND NOT (t.anonymous = TRUE AND t.user_id = c.user_id)""",
                Long.class, ownerId);
        return n == null ? 0 : n;
    }

    private static void keyset(StringBuilder sql, List<Object> args, String timeCol, String idCol, Cursor cur) {
        if (cur == null) {
            return;
        }
        Timestamp ts = Timestamp.from(cur.at());
        sql.append(" AND (").append(timeCol).append(" < ? OR (").append(timeCol).append(" = ? AND ").append(idCol)
                .append(" < ?))");
        args.add(ts);
        args.add(ts);
        args.add(cur.id());
    }
}
