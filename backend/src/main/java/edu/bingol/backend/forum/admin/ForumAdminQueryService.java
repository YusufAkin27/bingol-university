package edu.bingol.backend.forum.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.admin.ForumAdminDtos.ActionItem;
import edu.bingol.backend.forum.admin.ForumAdminDtos.AdminPage;
import edu.bingol.backend.forum.admin.ForumAdminDtos.AuthorRef;
import edu.bingol.backend.forum.admin.ForumAdminDtos.CategoryRef;
import edu.bingol.backend.forum.admin.ForumAdminDtos.ReportItem;
import edu.bingol.backend.forum.admin.ForumAdminDtos.ReportPreview;
import edu.bingol.backend.forum.admin.ForumAdminDtos.TopicItem;
import edu.bingol.backend.forum.moderation.ForumModerationActionRecord;
import edu.bingol.backend.forum.moderation.ForumModerationActionRepository;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetim paneli forum LISTELERI (salt okunur; sayfa tabanli, her sorgu LIMIT'li). ANONIM icerikte yazar kimligi
 * sorgulanmaz bile (author null); moderator yalniz icerik uzerinde eylem alir.
 */
@Service
public class ForumAdminQueryService {

    static final int MAX_SIZE = 50;
    private static final Set<String> TYPES = Set.of("FORUM_TOPIC", "FORUM_COMMENT");
    private static final Set<String> REASONS = Set.of("SPAM", "HARASSMENT", "INAPPROPRIATE", "IMPERSONATION",
            "PERSONAL_INFO", "OTHER");

    private final NamedParameterJdbcTemplate jdbc;
    private final ForumModerationActionRepository actions;

    public ForumAdminQueryService(NamedParameterJdbcTemplate jdbc, ForumModerationActionRepository actions) {
        this.jdbc = jdbc;
        this.actions = actions;
    }

    // --- sikayet kuyrugu ---

    /**
     * status: OPEN (varsayilan) | RESOLVED | ALL; type: FORUM_TOPIC | FORUM_COMMENT | bos; reason: sebebi icerenler.
     * En cok acik sikayet alan once.
     */
    @Transactional(readOnly = true)
    public AdminPage<ReportItem> reports(String status, String type, String reason, int page, int size) {
        String st = status == null || status.isBlank() ? "OPEN" : status.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("OPEN", "RESOLVED", "ALL").contains(st)) {
            throw badFilter();
        }
        String tp = type == null || type.isBlank() ? null : type.trim().toUpperCase(Locale.ROOT);
        if (tp != null && !TYPES.contains(tp)) {
            throw badFilter();
        }
        String rs = reason == null || reason.isBlank() ? null : reason.trim().toUpperCase(Locale.ROOT);
        if (rs != null && !REASONS.contains(rs)) {
            throw badFilter();
        }
        int sz = clampSize(size);
        int pg = Math.max(page, 0);
        List<String> having = new ArrayList<>();
        if ("OPEN".equals(st)) {
            having.add("SUM(CASE WHEN r.status = 'OPEN' THEN 1 ELSE 0 END) > 0");
        } else if ("RESOLVED".equals(st)) {
            having.add("SUM(CASE WHEN r.status = 'OPEN' THEN 1 ELSE 0 END) = 0");
        }
        MapSqlParameterSource p = new MapSqlParameterSource().addValue("lim", sz + 1).addValue("off", (long) pg * sz);
        if (tp != null) {
            p.addValue("tp", tp);
        }
        if (rs != null) {
            having.add("SUM(CASE WHEN r.reason = :rs THEN 1 ELSE 0 END) > 0");
            p.addValue("rs", rs);
        }
        List<Group> groups = jdbc.query("SELECT r.target_type AS tt, r.target_id AS tid, COUNT(*) AS total, "
                + "SUM(CASE WHEN r.status = 'OPEN' THEN 1 ELSE 0 END) AS open_cnt, MIN(r.created_at) AS first_at, "
                + "MAX(r.created_at) AS last_at, MAX(r.id) AS last_id FROM report r "
                + "WHERE r.target_type IN ('FORUM_TOPIC', 'FORUM_COMMENT') " + (tp != null ? "AND r.target_type = :tp " : "")
                + "GROUP BY r.target_type, r.target_id " + (having.isEmpty() ? "" : "HAVING " + String.join(" AND ", having) + " ")
                + "ORDER BY open_cnt DESC, last_at DESC, tid DESC LIMIT :lim OFFSET :off", p,
                (rset, i) -> new Group(rset.getString("tt"), rset.getLong("tid"), rset.getLong("total"),
                        rset.getLong("open_cnt"), iso(rset.getTimestamp("first_at")), iso(rset.getTimestamp("last_at")),
                        rset.getLong("last_id")));
        boolean more = groups.size() > sz;
        List<Group> cut = more ? groups.subList(0, sz) : groups;
        return AdminPage.of(enrichReports(cut), more ? String.valueOf(pg + 1) : null, pg, sz, more, null);
    }

    private record Group(String type, Long id, long total, long open, String first, String last, long lastId) {}

    private List<ReportItem> enrichReports(List<Group> groups) {
        if (groups.isEmpty()) {
            return List.of();
        }
        List<Long> topicIds = ids(groups, "FORUM_TOPIC");
        List<Long> commentIds = ids(groups, "FORUM_COMMENT");
        Map<Long, Content> topics = topicIds.isEmpty() ? Map.of() : topicContent(topicIds);
        Map<Long, Content> comments = commentIds.isEmpty() ? Map.of() : commentContent(commentIds);
        // yorumun ait oldugu konu (kategori/baslik icin)
        Set<Long> parentIds = new HashSet<>();
        comments.values().forEach(c -> parentIds.add(c.topicId()));
        parentIds.removeAll(topics.keySet());
        Map<Long, Content> parents = new HashMap<>(topics);
        if (!parentIds.isEmpty()) {
            parents.putAll(topicContent(new ArrayList<>(parentIds)));
        }
        Map<String, Map<String, Long>> reasons = new HashMap<>();
        Map<String, Long> firstOpen = new HashMap<>();
        Map<String, String> notes = new HashMap<>();
        for (String type : List.of("FORUM_TOPIC", "FORUM_COMMENT")) {
            List<Long> ids = "FORUM_TOPIC".equals(type) ? topicIds : commentIds;
            if (ids.isEmpty()) {
                continue;
            }
            MapSqlParameterSource p = new MapSqlParameterSource().addValue("tp", type).addValue("ids", ids);
            jdbc.query("SELECT target_id, reason, COUNT(*) AS n, MIN(id) AS first_id FROM report WHERE target_type = :tp "
                    + "AND target_id IN (:ids) AND status = 'OPEN' GROUP BY target_id, reason", p, rset -> {
                String key = type + ":" + rset.getLong("target_id");
                reasons.computeIfAbsent(key, k -> new LinkedHashMap<>()).put(rset.getString("reason"), rset.getLong("n"));
                firstOpen.merge(key, rset.getLong("first_id"), Math::min);
            });
            // en son acik sikayet notu (reporter yazisi; sahip kimligi icermez)
            jdbc.query("SELECT r.target_id, r.note FROM report r WHERE r.target_type = :tp AND r.target_id IN (:ids) "
                    + "AND r.status = 'OPEN' AND r.note IS NOT NULL AND r.id = (SELECT MAX(r2.id) FROM report r2 "
                    + "WHERE r2.target_type = r.target_type AND r2.target_id = r.target_id AND r2.status = 'OPEN' "
                    + "AND r2.note IS NOT NULL)", p, rset -> {
                notes.put(type + ":" + rset.getLong("target_id"), rset.getString("note"));
            });
        }
        Map<Long, String> categories = categoryNames(parents.values().stream().map(Content::categoryId)
                .filter(c -> c != null).distinct().toList());
        Map<Long, String> authors = authorNames(groups, topics, comments);
        List<ReportItem> out = new ArrayList<>();
        for (Group g : groups) {
            boolean isTopic = "FORUM_TOPIC".equals(g.type());
            Content c = isTopic ? topics.get(g.id()) : comments.get(g.id());
            Content topic = c == null ? null : isTopic ? c : parents.get(c.topicId());
            String key = g.type() + ":" + g.id();
            Long catId = topic == null ? null : topic.categoryId();
            CategoryRef cat = catId == null ? null : new CategoryRef(catId, categories.get(catId));
            boolean anon = c != null && c.anonymous();
            AuthorRef author = c == null || anon ? null : new AuthorRef(c.userId(), authors.get(c.userId()));
            String contentStatus = c == null ? "MISSING" : c.deleted() ? "DELETED" : c.status();
            ReportPreview preview = new ReportPreview(topic == null ? null : topic.title(),
                    c == null ? null : snippet(c.body(), 400), anon, author, contentStatus,
                    topic != null && topic.pinned(), topic != null && topic.locked());
            Map<String, Long> counts = reasons.getOrDefault(key, Map.of());
            List<String> reasonList = counts.entrySet().stream()
                    .sorted(Map.Entry.<String, Long>comparingByValue(Comparator.reverseOrder())).map(Map.Entry::getKey).toList();
            Long resolveId = firstOpen.get(key);
            out.add(new ReportItem(resolveId != null ? resolveId : g.lastId(), g.type(), g.id(),
                    topic == null ? null : topic.id(), g.open() > 0 ? "OPEN" : "RESOLVED", reasonList, counts,
                    notes.get(key), g.open() > 0 ? g.open() : g.total(), g.open(), g.total(), resolveId, cat, preview,
                    g.last(), g.first(), g.last()));
        }
        return out;
    }

    private static List<Long> ids(List<Group> groups, String type) {
        return groups.stream().filter(g -> type.equals(g.type())).map(Group::id).toList();
    }

    /** Ortak icerik satiri (konu ya da yorum). */
    private record Content(Long id, Long userId, boolean anonymous, String status, boolean deleted, Long categoryId,
                           Long topicId, String title, String body, boolean pinned, boolean locked) {}

    private Map<Long, Content> topicContent(List<Long> ids) {
        Map<Long, Content> out = new HashMap<>();
        jdbc.query("SELECT id, user_id, anonymous, status, deleted_at, category_id, title, body, pinned_at, locked_at "
                + "FROM forum_topic WHERE id IN (:ids)", new MapSqlParameterSource("ids", ids), rs -> {
            Long id = rs.getLong("id");
            out.put(id, new Content(id, rs.getLong("user_id"), rs.getBoolean("anonymous"), rs.getString("status"),
                    rs.getObject("deleted_at") != null, (Long) rs.getObject("category_id"), id, rs.getString("title"),
                    rs.getString("body"), rs.getObject("pinned_at") != null, rs.getObject("locked_at") != null));
        });
        return out;
    }

    private Map<Long, Content> commentContent(List<Long> ids) {
        Map<Long, Content> out = new HashMap<>();
        jdbc.query("SELECT id, topic_id, user_id, anonymous, status, deleted_at, body FROM forum_comment WHERE id IN (:ids)",
                new MapSqlParameterSource("ids", ids), rs -> {
            Long id = rs.getLong("id");
            out.put(id, new Content(id, rs.getLong("user_id"), rs.getBoolean("anonymous"), rs.getString("status"),
                    rs.getObject("deleted_at") != null, null, rs.getLong("topic_id"), null, rs.getString("body"), false, false));
        });
        return out;
    }

    private Map<Long, String> categoryNames(List<Long> ids) {
        Map<Long, String> out = new HashMap<>();
        if (ids.isEmpty()) {
            return out;
        }
        jdbc.query("SELECT id, name_tr FROM forum_category WHERE id IN (:ids)", new MapSqlParameterSource("ids", ids),
                rs -> {
                    out.put(rs.getLong("id"), rs.getString("name_tr"));
                });
        return out;
    }

    /** Yalniz ANONIM OLMAYAN iceriklerin yazar adlari (anonim icerigin kullanici kimligi sorgulanmaz). */
    private Map<Long, String> authorNames(List<Group> groups, Map<Long, Content> topics, Map<Long, Content> comments) {
        Set<Long> userIds = new HashSet<>();
        for (Group g : groups) {
            Content c = "FORUM_TOPIC".equals(g.type()) ? topics.get(g.id()) : comments.get(g.id());
            if (c != null && !c.anonymous()) {
                userIds.add(c.userId());
            }
        }
        return userNames(userIds);
    }

    private Map<Long, String> userNames(Set<Long> userIds) {
        Map<Long, String> out = new HashMap<>();
        if (userIds.isEmpty()) {
            return out;
        }
        jdbc.query("SELECT id, display_name FROM app_user WHERE id IN (:ids)",
                new MapSqlParameterSource("ids", new ArrayList<>(userIds)), rs -> {
                    out.put(rs.getLong("id"), rs.getString("display_name"));
                });
        return out;
    }

    // --- islem kayitlari ---

    /** targetType: FORUM_TOPIC | FORUM_COMMENT (TOPIC | COMMENT kisaltmasi da kabul edilir). */
    @Transactional(readOnly = true)
    public AdminPage<ActionItem> actions(String targetType, String action, int page, int size) {
        String tt = targetType == null || targetType.isBlank() ? null : targetType.trim().toUpperCase(Locale.ROOT);
        if (tt != null && !tt.startsWith("FORUM_")) {
            tt = "FORUM_" + tt;
        }
        if (tt != null && !TYPES.contains(tt)) {
            throw badFilter();
        }
        String ac = action == null || action.isBlank() ? null : action.trim().toUpperCase(Locale.ROOT);
        int sz = clampSize(size);
        int pg = Math.max(page, 0);
        Slice<ForumModerationActionRecord> slice = actions.list(tt, ac, PageRequest.of(pg, sz));
        Set<Long> actorIds = new HashSet<>();
        slice.getContent().forEach(a -> {
            if (a.getActorId() != null) {
                actorIds.add(a.getActorId());
            }
        });
        Map<Long, String> names = userNames(actorIds);
        List<ActionItem> items = slice.getContent().stream()
                .map(a -> new ActionItem(a.getId(), a.getTargetType(), a.getTargetId(), a.getTopicId(), a.getAction(),
                        a.getReason(), a.getSource(), a.getActorId(),
                        a.getActorId() == null ? null : names.get(a.getActorId()),
                        a.getActorId() == null ? null : new AuthorRef(a.getActorId(), names.get(a.getActorId())),
                        a.getCreatedAt().toString()))
                .toList();
        return AdminPage.of(items, slice.hasNext() ? String.valueOf(pg + 1) : null, pg, sz, slice.hasNext(), null);
    }

    // --- konular ---

    /**
     * q: baslik/aciklama icinde arama; status: ACTIVE | REMOVED | DELETED | PINNED | LOCKED | ALL (varsayilan: sahibi
     * silmeyenler = ACTIVE + REMOVED). Yeniden eskiye.
     */
    @Transactional(readOnly = true)
    public AdminPage<TopicItem> topics(String q, String status, Long categoryId, int page, int size) {
        String st = status == null || status.isBlank() ? "DEFAULT" : status.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("DEFAULT", "ACTIVE", "REMOVED", "DELETED", "PINNED", "LOCKED", "ALL").contains(st)) {
            throw badFilter();
        }
        int sz = clampSize(size);
        int pg = Math.max(page, 0);
        MapSqlParameterSource p = new MapSqlParameterSource();
        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        switch (st) {
            case "DEFAULT" -> where.append(" AND t.deleted_at IS NULL");
            case "ACTIVE" -> where.append(" AND t.deleted_at IS NULL AND t.status = 'ACTIVE'");
            case "REMOVED" -> where.append(" AND t.deleted_at IS NULL AND t.status = 'REMOVED'");
            case "DELETED" -> where.append(" AND t.deleted_at IS NOT NULL");
            case "PINNED" -> where.append(" AND t.deleted_at IS NULL AND t.pinned_at IS NOT NULL");
            case "LOCKED" -> where.append(" AND t.deleted_at IS NULL AND t.locked_at IS NOT NULL");
            default -> { }
        }
        if (categoryId != null) {
            where.append(" AND t.category_id = :cat");
            p.addValue("cat", categoryId);
        }
        String needle = q == null ? "" : q.strip();
        if (!needle.isEmpty()) {
            if (needle.length() > 100) {
                needle = needle.substring(0, 100);
            }
            where.append(" AND (LOWER(t.title) LIKE :q ESCAPE '!' OR LOWER(t.body) LIKE :q ESCAPE '!')");
            p.addValue("q", "%" + likeEscape(needle.toLowerCase(Locale.ROOT)) + "%");
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic t" + where, p, Long.class);
        MapSqlParameterSource lp = new MapSqlParameterSource(p.getValues()).addValue("lim", sz + 1)
                .addValue("off", (long) pg * sz);
        List<Row> rows = jdbc.query("SELECT t.id, t.user_id, t.anonymous, t.status, t.deleted_at, t.category_id, t.title, "
                + "t.body, t.pinned_at, t.locked_at, t.comment_count, t.like_count, t.removed_reason, t.created_at, "
                + "t.last_activity_at FROM forum_topic t" + where + " ORDER BY t.id DESC LIMIT :lim OFFSET :off", lp,
                (rs, i) -> new Row(rs.getLong("id"), rs.getLong("user_id"), rs.getBoolean("anonymous"),
                        rs.getString("status"), rs.getObject("deleted_at") != null, (Long) rs.getObject("category_id"),
                        rs.getString("title"), rs.getString("body"), rs.getObject("pinned_at") != null,
                        rs.getObject("locked_at") != null, rs.getLong("comment_count"), rs.getLong("like_count"),
                        rs.getString("removed_reason"), iso(rs.getTimestamp("created_at")),
                        iso(rs.getTimestamp("last_activity_at"))));
        boolean more = rows.size() > sz;
        List<Row> cut = more ? rows.subList(0, sz) : rows;
        List<Long> idList = cut.stream().map(Row::id).toList();
        Map<Long, Long> openReports = new HashMap<>();
        if (!idList.isEmpty()) {
            jdbc.query("SELECT target_id, COUNT(*) AS n FROM report WHERE target_type = 'FORUM_TOPIC' AND status = 'OPEN' "
                    + "AND target_id IN (:ids) GROUP BY target_id", new MapSqlParameterSource("ids", idList),
                    rs -> {
                        openReports.put(rs.getLong("target_id"), rs.getLong("n"));
                    });
        }
        Map<Long, String> categories = categoryNames(cut.stream().map(Row::categoryId).filter(c -> c != null).distinct().toList());
        Set<Long> userIds = new HashSet<>();
        cut.stream().filter(r -> !r.anonymous()).forEach(r -> userIds.add(r.userId()));
        Map<Long, String> names = userNames(userIds);
        List<TopicItem> items = cut.stream().map(r -> new TopicItem(r.id(), r.title(), snippet(r.body(), 200),
                r.categoryId(), r.categoryId() == null ? null : categories.get(r.categoryId()),
                r.categoryId() == null ? null : new CategoryRef(r.categoryId(), categories.get(r.categoryId())),
                r.deleted() ? "DELETED" : r.status(), r.pinned(), r.locked(), r.anonymous(),
                r.anonymous() ? null : new AuthorRef(r.userId(), names.get(r.userId())), r.comments(), r.likes(),
                openReports.getOrDefault(r.id(), 0L), r.removedReason(), r.createdAt(), r.lastActivityAt())).toList();
        return AdminPage.of(items, more ? String.valueOf(pg + 1) : null, pg, sz, more, total);
    }

    private record Row(Long id, Long userId, boolean anonymous, String status, boolean deleted, Long categoryId,
                       String title, String body, boolean pinned, boolean locked, long comments, long likes,
                       String removedReason, String createdAt, String lastActivityAt) {}

    // --- yardimcilar ---

    private static ApiException badFilter() {
        return new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_BAD_FILTER", "Geçersiz süzgeç değeri.");
    }

    private static int clampSize(int size) {
        return Math.min(Math.max(size, 1), MAX_SIZE);
    }

    private static String iso(Timestamp ts) {
        return ts == null ? null : ts.toInstant().toString();
    }

    static String snippet(String s, int max) {
        if (s == null) {
            return null;
        }
        return s.length() <= max ? s : s.substring(0, max) + "…";
    }

    /** LIKE ozel karakterleri (! kacis karakteri olarak secildi: '\\' H2/PostgreSQL farki yaratmasin). */
    static String likeEscape(String s) {
        return s.replace("!", "!!").replace("%", "!%").replace("_", "!_");
    }
}
