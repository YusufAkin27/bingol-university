package edu.bingol.backend.forum.comment;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * forum_comment okuma SQL'i (tek yer). Kurallar: her liste sorgusu LIMIT'li, IN listeleri bos olmaz (tek "-1"
 * bekcisi), dinamik parca yok (siralama beyaz listeli sabit metinler), tum degerler parametre.
 */
@Component
class ForumCommentStore {

    private static final Set<Long> NO_HIDDEN = Set.of(-1L);

    static final String COLS = "c.id, c.topic_id, c.user_id, c.parent_comment_id, c.root_comment_id, c.depth, c.body, "
            + "c.anonymous, c.like_count, c.reply_count, c.status, c.removed_reason, c.created_at, c.edited_at, c.deleted_at";

    /** Listelenir: canli, ya da altinda listelenen yaniti olan yer tutucu. */
    static final String LISTED = "((c.deleted_at IS NULL AND c.status = 'ACTIVE') OR c.reply_count > 0)";

    /**
     * EN IYI puani (tam sayi; imlec karsilastirmasi kayan nokta esitligine dusmesin diye):
     * floor(1e6 * (2*begeni + yanit + 1) / (yas_saat + 2)^1.5). :asOf imlecte tasinan an (ilk sayfada sunucu saati):
     * sayfalar arasi siralama o ana gore sabittir.
     */
    static final String BEST_SCORE = "CAST(FLOOR(1000000.0 * (2.0 * c.like_count + c.reply_count + 1.0) / "
            + "POWER(GREATEST(:asOf - EXTRACT(EPOCH FROM c.created_at), 0) / 3600.0 + 2.0, 1.5)) AS BIGINT)";

    private static final RowMapper<ForumCommentRow> MAPPER = ForumCommentStore::map;

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;

    ForumCommentStore(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
    }

    private static ForumCommentRow map(ResultSet rs, int i) throws SQLException {
        return new ForumCommentRow(rs.getLong("id"), rs.getLong("topic_id"), rs.getLong("user_id"),
                nullableLong(rs, "parent_comment_id"), nullableLong(rs, "root_comment_id"), rs.getInt("depth"),
                rs.getString("body"), rs.getBoolean("anonymous"), rs.getInt("like_count"), rs.getInt("reply_count"),
                rs.getString("status"), rs.getString("removed_reason"), instant(rs, "created_at"),
                instant(rs, "edited_at"), instant(rs, "deleted_at"));
    }

    private static Long nullableLong(ResultSet rs, String col) throws SQLException {
        long v = rs.getLong(col);
        return rs.wasNull() ? null : v;
    }

    private static Instant instant(ResultSet rs, String col) throws SQLException {
        OffsetDateTime t = rs.getObject(col, OffsetDateTime.class);
        return t == null ? null : t.toInstant();
    }

    static Collection<Long> guard(Collection<Long> hidden) {
        return hidden == null || hidden.isEmpty() ? NO_HIDDEN : hidden;
    }

    // ---------------------------------------------------------------- tekil okuma

    Optional<ForumCommentRow> find(long id) {
        return jdbc.query("SELECT " + COLS + " FROM forum_comment c WHERE c.id = ?", MAPPER, id).stream().findFirst();
    }

    /** Satir kilidi (FOR UPDATE): yanit olusturma / silme / durum degisimi ayni satirda siralanir. */
    Optional<ForumCommentRow> findForUpdate(long id) {
        return jdbc.query("SELECT " + COLS + " FROM forum_comment c WHERE c.id = ? FOR UPDATE", MAPPER, id)
                .stream().findFirst();
    }

    Optional<ForumCommentRow> findByIdempotencyKey(long userId, String key) {
        return jdbc.query("SELECT " + COLS + " FROM forum_comment c WHERE c.user_id = ? AND c.idempotency_key = ?",
                MAPPER, userId, key).stream().findFirst();
    }

    /** Verilen kimliklerin satirlari, ISTENEN SIRAYLA (bulunmayanlar atlanir). */
    List<ForumCommentRow> findAllOrdered(List<Long> ids) {
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<Long, ForumCommentRow> byId = new HashMap<>();
        named.query("SELECT " + COLS + " FROM forum_comment c WHERE c.id IN (:ids)",
                new MapSqlParameterSource("ids", ids), MAPPER).forEach(r -> byId.put(r.id(), r));
        List<ForumCommentRow> out = new ArrayList<>(ids.size());
        for (Long id : ids) {
            ForumCommentRow r = byId.get(id);
            if (r != null) {
                out.add(r);
            }
        }
        return out;
    }

    // ---------------------------------------------------------------- liste kimlikleri

    /** Ust duzey yorumlar, en yeni once. afterId null = ilk sayfa. */
    List<Long> topIdsNewest(long topicId, Collection<Long> hidden, Long afterId, int limit) {
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("t", topicId).addValue("h", guard(hidden))
                .addValue("n", limit);
        String cursor = "";
        if (afterId != null) {
            cursor = " AND c.id < :a";
            p.addValue("a", afterId);
        }
        return named.queryForList("SELECT c.id FROM forum_comment c WHERE c.topic_id = :t AND c.parent_comment_id IS NULL AND "
                + LISTED + " AND c.user_id NOT IN (:h)" + cursor + " ORDER BY c.id DESC LIMIT :n", p, Long.class);
    }

    List<Long> topIdsOldest(long topicId, Collection<Long> hidden, Long afterId, int limit) {
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("t", topicId).addValue("h", guard(hidden))
                .addValue("n", limit);
        String cursor = "";
        if (afterId != null) {
            cursor = " AND c.id > :a";
            p.addValue("a", afterId);
        }
        return named.queryForList("SELECT c.id FROM forum_comment c WHERE c.topic_id = :t AND c.parent_comment_id IS NULL AND "
                + LISTED + " AND c.user_id NOT IN (:h)" + cursor + " ORDER BY c.id ASC LIMIT :n", p, Long.class);
    }

    /** EN IYI: {id, puan} ciftleri; puan azalan, id azalan. afterScore/afterId null = ilk sayfa. */
    List<long[]> topIdsBest(long topicId, Collection<Long> hidden, long asOf, Long afterScore, Long afterId, int limit) {
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("t", topicId).addValue("h", guard(hidden))
                .addValue("asOf", asOf).addValue("n", limit);
        String cursor = "";
        if (afterScore != null && afterId != null) {
            cursor = " AND (" + BEST_SCORE + " < :cs OR (" + BEST_SCORE + " = :cs AND c.id < :ci))";
            p.addValue("cs", afterScore).addValue("ci", afterId);
        }
        return named.query("SELECT c.id AS cid, " + BEST_SCORE + " AS score FROM forum_comment c WHERE c.topic_id = :t "
                + "AND c.parent_comment_id IS NULL AND " + LISTED + " AND c.user_id NOT IN (:h)" + cursor
                + " ORDER BY score DESC, c.id DESC LIMIT :n", p,
                (rs, i) -> new long[] {rs.getLong("cid"), rs.getLong("score")});
    }

    /** Dogrudan yanitlar, eskiden yeniye (konusma sirasi). */
    List<Long> replyIds(long parentId, Collection<Long> hidden, Long afterId, int limit) {
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("p", parentId).addValue("h", guard(hidden))
                .addValue("n", limit);
        String cursor = "";
        if (afterId != null) {
            cursor = " AND c.id > :a";
            p.addValue("a", afterId);
        }
        return named.queryForList("SELECT c.id FROM forum_comment c WHERE c.parent_comment_id = :p AND " + LISTED
                + " AND c.user_id NOT IN (:h)" + cursor + " ORDER BY c.id ASC LIMIT :n", p, Long.class);
    }

    /** Her ust yorumun ilk {@code per} listelenen yanitinin kimligi (ust kimlik -> kimlikler, id artan). */
    Map<Long, List<Long>> previewIds(Collection<Long> parentIds, Collection<Long> hidden, int per) {
        Map<Long, List<Long>> out = new LinkedHashMap<>();
        if (parentIds.isEmpty()) {
            return out;
        }
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("ps", parentIds).addValue("h", guard(hidden))
                .addValue("per", per);
        named.query("SELECT t.cid, t.pid FROM (SELECT c.id AS cid, c.parent_comment_id AS pid, "
                + "ROW_NUMBER() OVER (PARTITION BY c.parent_comment_id ORDER BY c.id) AS rn FROM forum_comment c "
                + "WHERE c.parent_comment_id IN (:ps) AND " + LISTED + " AND c.user_id NOT IN (:h)) t "
                + "WHERE t.rn <= :per ORDER BY t.pid, t.cid", p, (rs, i) -> {
                    out.computeIfAbsent(rs.getLong("pid"), k -> new ArrayList<>()).add(rs.getLong("cid"));
                    return null;
                });
        return out;
    }

    /** Zincirdeki ata kimlikleri, kokten dogrudan ust yoruma dogru. Ust duzey yorumda bos. */
    List<Long> ancestorPath(ForumCommentRow c) {
        if (c.parentId() == null) {
            return List.of();
        }
        long root = c.rootId() != null ? c.rootId() : c.parentId();
        Map<Long, Long> parentOf = new HashMap<>();
        named.query("SELECT c.id AS cid, c.parent_comment_id AS pid FROM forum_comment c "
                + "WHERE c.id = :r OR c.root_comment_id = :r", new MapSqlParameterSource("r", root), (rs, i) -> {
                    long pid = rs.getLong("pid");
                    boolean noParent = rs.wasNull(); // wasNull son okunan sutun icindir: ONCE bakilir
                    parentOf.put(rs.getLong("cid"), noParent ? null : pid);
                    return null;
                });
        List<Long> rev = new ArrayList<>();
        Long cur = c.parentId();
        int guard = 0;
        while (cur != null && guard++ < 10_000) {
            rev.add(cur);
            cur = parentOf.get(cur);
        }
        Collections.reverse(rev);
        return rev;
    }

    // ---------------------------------------------------------------- yardimci okumalar

    Set<Long> likedAmong(long viewerId, Collection<Long> commentIds) {
        if (commentIds.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(named.queryForList("SELECT comment_id FROM forum_comment_like WHERE user_id = :u "
                + "AND comment_id IN (:ids)", new MapSqlParameterSource().addValue("u", viewerId)
                .addValue("ids", commentIds), Long.class));
    }

    Set<Long> savedAmong(long viewerId, Collection<Long> commentIds) {
        if (commentIds.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(named.queryForList("SELECT target_id FROM forum_bookmark WHERE user_id = :u "
                + "AND target_type = 'COMMENT' AND target_id IN (:ids)", new MapSqlParameterSource()
                .addValue("u", viewerId).addValue("ids", commentIds), Long.class));
    }

    boolean likeExists(long userId, long commentId) {
        Integer c = jdbc.queryForObject("SELECT COUNT(*) FROM forum_comment_like WHERE comment_id = ? AND user_id = ?",
                Integer.class, commentId, userId);
        return c != null && c > 0;
    }

    int likeCount(long commentId) {
        List<Integer> n = jdbc.queryForList("SELECT like_count FROM forum_comment WHERE id = ?", Integer.class, commentId);
        return n.isEmpty() || n.get(0) == null ? 0 : n.get(0);
    }
}
