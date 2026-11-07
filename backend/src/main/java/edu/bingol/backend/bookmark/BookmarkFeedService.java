package edu.bingol.backend.bookmark;

import edu.bingol.backend.bookmark.dto.BookmarkItem;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.news.NewsRow;
import edu.bingol.backend.news.dto.NewsSummary;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaRepository;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Birlesik Kaydedilenler: genel {@code bookmark} tablosu (NEWS/EVENT/COMMUNITY/POLL/ACADEMIC) + {@code post_save} (POST)
 * + {@code forum_bookmark} (FORUM_TOPIC/FORUM_COMMENT) tek imecli listede. Veri tasinmaz; yalniz okuma birlestirmesi.
 * Sema-bagimsiz SQL kullanilir (H2 ile test edilebilir). Imec = son ham satirin kaydedilme zamani (epoch mikrosaniye).
 */
@Service
public class BookmarkFeedService {

    public static final String ALL = "ALL";
    static final Set<String> LIST_TYPES = Set.of("NEWS", "EVENT", "COMMUNITY", "POLL", "ACADEMIC", "POST",
            "FORUM_TOPIC", "FORUM_COMMENT");
    private static final String INVALID = "Geçersiz kayıt türü. Geçerli değerler: NEWS, EVENT, COMMUNITY, POLL, ACADEMIC.";

    private final JdbcTemplate jdbc;
    private final BookmarkRepository repo;
    private final NewsRepository news;
    private final BookmarkService newsBookmarks;
    private final PostRepository posts;
    private final PostMediaRepository postMedia;

    public BookmarkFeedService(JdbcTemplate jdbc, BookmarkRepository repo, NewsRepository news,
                               BookmarkService newsBookmarks, PostRepository posts, PostMediaRepository postMedia) {
        this.jdbc = jdbc;
        this.repo = repo;
        this.news = news;
        this.newsBookmarks = newsBookmarks;
        this.posts = posts;
        this.postMedia = postMedia;
    }

    /** Yol degiskeni (news, event...) -> hedef; gonderi/forum bu uclardan kaydedilmez. */
    public static BookmarkTarget parseTarget(String raw) {
        try {
            return BookmarkTarget.valueOf(raw == null ? "" : raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "BOOKMARK_TYPE_INVALID", INVALID);
        }
    }

    /** Liste suzgeci: ALL ya da {@link #LIST_TYPES} elemani (buyuk/kucuk harf farksiz). */
    public static String parseFilter(String raw) {
        String t = raw == null ? ALL : raw.trim().toUpperCase(Locale.ROOT);
        if (t.isEmpty()) {
            return ALL;
        }
        if (!ALL.equals(t) && !LIST_TYPES.contains(t)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "BOOKMARK_TYPE_INVALID", INVALID);
        }
        return t;
    }

    /** Idempotent kaydet; hedef bakana gorunur degilse 404 NOT_FOUND. */
    @Transactional
    public void add(Long uid, BookmarkTarget target, Long id) {
        if (target == BookmarkTarget.NEWS) {
            newsBookmarks.addNews(uid, id);
            return;
        }
        if (!exists(uid, target, id)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "İçerik bulunamadı.");
        }
        if (repo.existsByUserIdAndTargetTypeAndTargetId(uid, target, id)) {
            return;
        }
        if (repo.countByUserId(uid) >= BookmarkService.MAX_PER_USER) {
            throw new ApiException(HttpStatus.CONFLICT, "BOOKMARK_LIMIT",
                    "En fazla " + BookmarkService.MAX_PER_USER + " kayıt tutulabilir. Önce bazılarını kaldırın.",
                    String.valueOf(BookmarkService.MAX_PER_USER));
        }
        repo.insertIfAbsent(uid, target.name(), id);
    }

    /** Idempotent: kayit yoksa da basarili. */
    @Transactional
    public void remove(Long uid, BookmarkTarget target, Long id) {
        repo.remove(uid, target, id);
    }

    /** Liste ekranlarinda isaret icin bir turun kayitli kimlikleri (en fazla 1000). */
    @Transactional(readOnly = true)
    public List<Long> ids(Long uid, BookmarkTarget target) {
        return repo.targetIds(uid, target, PageRequest.of(0, BookmarkService.MAX_PER_USER));
    }

    private boolean exists(Long uid, BookmarkTarget t, Long id) {
        String sql;
        Object[] args;
        switch (t) {
            case EVENT -> {
                sql = "SELECT COUNT(*) FROM user_event WHERE id = ? AND status = 'ACTIVE'";
                args = new Object[] {id};
            }
            case COMMUNITY -> {
                sql = "SELECT COUNT(*) FROM community c WHERE c.id = ? AND c.status = 'ACTIVE' AND (c.visibility = 'PUBLIC' "
                        + "OR EXISTS (SELECT 1 FROM community_member m WHERE m.community_id = c.id AND m.user_id = ? "
                        + "AND m.status = 'ACTIVE'))";
                args = new Object[] {id, uid};
            }
            case POLL -> {
                sql = "SELECT COUNT(*) FROM poll WHERE id = ? AND status IN ('OPEN', 'CLOSED')";
                args = new Object[] {id};
            }
            case ACADEMIC -> {
                sql = "SELECT COUNT(*) FROM academic_event WHERE id = ? AND published = TRUE";
                args = new Object[] {id};
            }
            default -> throw new IllegalArgumentException(t.name());
        }
        Integer n = jdbc.queryForObject(sql, Integer.class, args);
        return n != null && n > 0;
    }

    private record Raw(String type, Long id, Instant savedAt) {}

    @Transactional(readOnly = true)
    public CursorPage<BookmarkItem> list(Long uid, String filter, Long cursorMicros, int size) {
        int s = CursorPage.clampSize(size);
        Instant before = cursorMicros == null ? Instant.parse("2999-01-01T00:00:00Z") : fromMicros(cursorMicros);
        StringBuilder sql = new StringBuilder("SELECT t, tid, saved_at FROM ("
                + "SELECT CAST(target_type AS VARCHAR(16)) AS t, target_id AS tid, created_at AS saved_at FROM bookmark WHERE user_id = ? "
                + "UNION ALL SELECT CAST('POST' AS VARCHAR(16)), post_id, created_at FROM post_save WHERE user_id = ? "
                + "UNION ALL SELECT CAST('FORUM_' || target_type AS VARCHAR(16)), target_id, created_at FROM forum_bookmark WHERE user_id = ?"
                + ") x WHERE saved_at < ?");
        List<Object> args = new ArrayList<>(List.of(uid, uid, uid, Timestamp.from(before)));
        if (!ALL.equals(filter)) {
            sql.append(" AND t = ?");
            args.add(filter);
        }
        sql.append(" ORDER BY saved_at DESC, tid DESC LIMIT ?");
        args.add(s + 1);
        List<Raw> rows = jdbc.query(sql.toString(),
                (rs, i) -> new Raw(rs.getString(1), rs.getLong(2), rs.getTimestamp(3).toInstant()), args.toArray());

        boolean more = rows.size() > s;
        List<Raw> page = more ? rows.subList(0, s) : rows;
        Long next = more ? toMicros(page.get(page.size() - 1).savedAt()) : null;

        Map<String, Map<Long, BookmarkItem>> resolved = new HashMap<>();
        for (String type : LIST_TYPES) {
            List<Raw> ofType = page.stream().filter(r -> r.type().equals(type)).toList();
            if (!ofType.isEmpty()) {
                resolved.put(type, resolve(uid, type, ofType));
            }
        }
        // Kaynagi silinmis/gizlenmis/gorunmez hedefler sessizce dusulur (sayfa size'dan kisa olabilir)
        List<BookmarkItem> items = page.stream()
                .map(r -> resolved.getOrDefault(r.type(), Map.of()).get(r.id()))
                .filter(Objects::nonNull).toList();
        return new CursorPage<>(items, next);
    }

    static long toMicros(Instant i) {
        return i.getEpochSecond() * 1_000_000L + i.getNano() / 1000;
    }

    static Instant fromMicros(long micros) {
        return Instant.ofEpochSecond(Math.floorDiv(micros, 1_000_000L), Math.floorMod(micros, 1_000_000L) * 1000L);
    }

    private static String in(Collection<?> c) {
        return String.join(",", Collections.nCopies(c.size(), "?"));
    }

    private Map<Long, BookmarkItem> resolve(Long uid, String type, List<Raw> raws) {
        List<Long> ids = raws.stream().map(Raw::id).toList();
        Map<Long, Instant> savedAt = raws.stream().collect(Collectors.toMap(Raw::id, Raw::savedAt, (a, b) -> a));
        Map<Long, BookmarkItem> out = new LinkedHashMap<>();
        switch (type) {
            case "NEWS" -> {
                for (NewsRow n : news.findByIdInAndHiddenFalse(ids)) {
                    out.put(n.getId(), new BookmarkItem(type, n.getId(), savedAt.get(n.getId()), n.getTitle(),
                            n.getType() == null ? null : n.getType().name(), n.getImageUrl(), "/news/" + n.getId(),
                            NewsSummary.of(n)));
                }
            }
            case "EVENT" -> fill(out, type, savedAt, ids, "/events/",
                    "SELECT id, title, location, cover_url FROM user_event WHERE status = 'ACTIVE' AND id IN (%s)");
            case "POLL" -> fill(out, type, savedAt, ids, "/polls/",
                    "SELECT id, title, status, CAST(NULL AS VARCHAR(10)) FROM poll WHERE status IN ('OPEN', 'CLOSED') AND id IN (%s)");
            case "ACADEMIC" -> fill(out, type, savedAt, ids, "/academic/events/",
                    "SELECT id, title, kind, CAST(NULL AS VARCHAR(10)) FROM academic_event WHERE published = TRUE AND id IN (%s)");
            case "COMMUNITY" -> fill(out, type, savedAt, ids, "/communities/",
                    "SELECT c.id, c.name, c.category, COALESCE(c.logo_url, c.cover_url) FROM community c WHERE c.status = 'ACTIVE' "
                            + "AND (c.visibility = 'PUBLIC' OR EXISTS (SELECT 1 FROM community_member m WHERE m.community_id = c.id "
                            + "AND m.user_id = " + uid.longValue() + " AND m.status = 'ACTIVE')) AND c.id IN (%s)");
            case "FORUM_TOPIC" -> fill(out, type, savedAt, ids, "/forum/topics/",
                    "SELECT id, title, CAST(NULL AS VARCHAR(10)), CAST(NULL AS VARCHAR(10)) FROM forum_topic "
                            + "WHERE deleted_at IS NULL AND status = 'ACTIVE' AND id IN (%s)");
            // Yazar bilgisi (anonim olabilir) ASLA doldurulmaz; yalniz metin ozeti ve konu basligi
            case "FORUM_COMMENT" -> fill(out, type, savedAt, ids, "/forum/comments/",
                    "SELECT c.id, SUBSTRING(c.body, 1, 140), t.title, CAST(NULL AS VARCHAR(10)) FROM forum_comment c "
                            + "JOIN forum_topic t ON t.id = c.topic_id WHERE c.deleted_at IS NULL AND c.status = 'ACTIVE' "
                            + "AND t.deleted_at IS NULL AND t.status = 'ACTIVE' AND c.id IN (%s)");
            case "POST" -> {
                List<Post> visible = posts.visibleAmong(uid, ids);
                Map<Long, PostMedia> first = new HashMap<>();
                if (!visible.isEmpty()) {
                    for (PostMedia m : postMedia.findByPostIdIn(visible.stream().map(Post::getId).toList())) {
                        if (m.getHiddenAt() == null) {
                            first.merge(m.getPostId(), m, (a, b) -> a.getPosition() <= b.getPosition() ? a : b);
                        }
                    }
                }
                for (Post p : visible) {
                    PostMedia m = first.get(p.getId());
                    String body = p.getBody();
                    String title = body == null ? "" : body.length() > 140 ? body.substring(0, 140) : body;
                    out.put(p.getId(), new BookmarkItem(type, p.getId(), savedAt.get(p.getId()), title, null,
                            m == null ? null : "/api/posts/media/" + m.getId() + "?thumb=true", "/posts/" + p.getId(), null));
                }
            }
            default -> { }
        }
        return out;
    }

    /** Sutunlar: 1 id, 2 baslik, 3 alt baslik, 4 gorsel. sqlTemplate'teki %s IN yer tutuculari ile doldurulur. */
    private void fill(Map<Long, BookmarkItem> out, String type, Map<Long, Instant> savedAt, List<Long> ids,
                      String linkBase, String sqlTemplate) {
        jdbc.query(String.format(sqlTemplate, in(ids)), rs -> {
            long id = rs.getLong(1);
            out.put(id, new BookmarkItem(type, id, savedAt.get(id), rs.getString(2), rs.getString(3), rs.getString(4),
                    linkBase + id, null));
        }, ids.toArray());
    }
}
