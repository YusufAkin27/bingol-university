package edu.bingol.backend.post.social;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostViewAssembler;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** #etiket sorgulari: gundem (48 saat, saatlik onbellek), etiket akisi, oneri. */
@Service
public class HashtagService {

    public record TagCount(String tag, String display, long postCount) {}

    static final Duration TRENDING_WINDOW = Duration.ofHours(48);
    static final Duration TRENDING_TTL = Duration.ofHours(1);
    static final int TRENDING_KEEP = 20;

    private final JdbcTemplate jdbc;
    private final HashtagRepository tags;
    private final SocialFeedRepository feeds;
    private final PostViewAssembler assembler;
    private final Clock clock;

    private volatile List<TagCount> cache = List.of();
    private volatile Instant cachedAt = Instant.EPOCH;

    public HashtagService(JdbcTemplate jdbc, HashtagRepository tags, SocialFeedRepository feeds,
                          PostViewAssembler assembler, Clock clock) {
        this.jdbc = jdbc;
        this.tags = tags;
        this.feeds = feeds;
        this.assembler = assembler;
        this.clock = clock;
    }

    public List<TagCount> trending(int size) {
        int n = size <= 0 ? 10 : Math.min(size, TRENDING_KEEP);
        Instant now = clock.instant();
        if (cachedAt.plus(TRENDING_TTL).isBefore(now)) {
            cache = computeTrending(now);
            cachedAt = now;
        }
        List<TagCount> c = cache;
        return c.size() <= n ? c : c.subList(0, n);
    }

    /** Test/yonetim: onbellegi at. */
    public void clearCache() {
        cachedAt = Instant.EPOCH;
    }

    private List<TagCount> computeTrending(Instant now) {
        return jdbc.query("SELECT t.tag, t.display, COUNT(*) AS c FROM post_hashtag l "
                + "JOIN hashtag t ON t.id = l.hashtag_id JOIN post p ON p.id = l.post_id "
                + "WHERE p.created_at >= ? AND p.deleted_at IS NULL AND p.hidden_at IS NULL "
                + "GROUP BY t.id, t.tag, t.display ORDER BY c DESC, t.tag LIMIT " + TRENDING_KEEP,
                (rs, i) -> new TagCount(rs.getString(1), rs.getString(2), rs.getLong(3)),
                Timestamp.from(now.minus(TRENDING_WINDOW)));
    }

    @Transactional(readOnly = true)
    public List<TagCount> suggest(String q) {
        String key = SocialText.fold(q == null ? "" : q);
        if (key.isEmpty() || key.length() > SocialText.TAG_MAX) {
            return List.of();
        }
        String like = key.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%";
        return jdbc.query("SELECT t.tag, t.display, (SELECT COUNT(*) FROM post_hashtag l JOIN post p ON p.id = l.post_id "
                + "WHERE l.hashtag_id = t.id AND p.deleted_at IS NULL AND p.hidden_at IS NULL) AS c "
                + "FROM hashtag t WHERE t.tag LIKE ? ESCAPE '\\' ORDER BY c DESC, t.tag LIMIT 8",
                (rs, i) -> new TagCount(rs.getString(1), rs.getString(2), rs.getLong(3)), like).stream()
                .filter(t -> t.postCount() > 0).toList();
    }

    @Transactional(readOnly = true)
    public FeedPage posts(Long viewer, String rawTag, String cursor, int size) {
        if (!SocialText.validTag(rawTag)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "HASHTAG_INVALID", "Geçersiz etiket.");
        }
        int n = size <= 0 ? 10 : Math.min(size, 20);
        Hashtag h = tags.findByTag(SocialText.fold(rawTag)).orElse(null);
        if (h == null) {
            return new FeedPage(List.of(), null);
        }
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<Post> rows = c == null ? feeds.hashtagFirst(viewer, h.getId(), PageRequest.of(0, n + 1))
                : feeds.hashtagAfter(viewer, h.getId(), c.at(), c.id(), PageRequest.of(0, n + 1));
        boolean more = rows.size() > n;
        List<Post> items = more ? rows.subList(0, n) : rows;
        String next = more ? PostCursor.latest(items.get(items.size() - 1).getCreatedAt(),
                items.get(items.size() - 1).getId()) : null;
        return new FeedPage(assembler.assemble(viewer, items), next);
    }
}
