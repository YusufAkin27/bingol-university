package edu.bingol.backend.post.story;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.PostDtos.MediaView;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.post.story.StoryDtos.AuthorView;
import edu.bingol.backend.post.story.StoryDtos.CreateRequest;
import edu.bingol.backend.post.story.StoryDtos.StoryView;
import edu.bingol.backend.post.story.StoryDtos.TrayItem;
import edu.bingol.backend.post.story.StoryDtos.Viewer;
import edu.bingol.backend.post.story.StoryDtos.ViewerPage;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 24 saatlik hikayeler. Gorunurluk: dogrulanmis herkes; engel iliskisinde yok. Yanit/tepki yok. Medya
 * {@code POST /api/posts/media} ile yuklenir, burada {@code post_media.story_id} ile baglanir.
 */
@Service
public class StoryService {

    private static final Pattern COLOR = Pattern.compile("#[0-9A-Fa-f]{6}");
    private static final String DEFAULT_BG = "#1B4F9C";
    static final int TRAY_MAX = 200;

    private final StoryRepository stories;
    private final StorySeenRepository seen;
    private final PostMediaRepository media;
    private final UserRepository users;
    private final BlockService blocks;
    private final PublicProfileMapper profiles;
    private final ContentGuard guard;
    private final JdbcTemplate jdbc;
    private final Clock clock;
    private final int videoMaxSeconds;
    private final int ttlHours;

    public StoryService(StoryRepository stories, StorySeenRepository seen, PostMediaRepository media,
                        UserRepository users, BlockService blocks, PublicProfileMapper profiles, ContentGuard guard,
                        JdbcTemplate jdbc, Clock clock, @Value("${app.story.video-max-seconds:30}") int videoMaxSeconds,
                        @Value("${app.story.ttl-hours:24}") int ttlHours) {
        this.stories = stories;
        this.seen = seen;
        this.media = media;
        this.users = users;
        this.blocks = blocks;
        this.profiles = profiles;
        this.guard = guard;
        this.jdbc = jdbc;
        this.clock = clock;
        this.videoMaxSeconds = videoMaxSeconds;
        this.ttlHours = Math.max(1, ttlHours);
    }

    // ---------------------------------------------------------------- olustur / sil

    @Transactional
    public StoryView create(Long uid, CreateRequest req) {
        String caption = norm(req.caption());
        String text = norm(req.text());
        if ((caption != null && caption.length() > StoryDtos.MAX_TEXT) || (text != null && text.length() > StoryDtos.MAX_TEXT)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "STORY_TOO_LONG", "Hikaye metni en çok {0} karakter olabilir.",
                    String.valueOf(StoryDtos.MAX_TEXT));
        }
        guard.assertClean(ContentGuard.Entity.POST, "caption", uid, caption);
        guard.assertClean(ContentGuard.Entity.POST, "text", uid, text);
        Story s = new Story();
        s.setAuthorId(uid);
        Instant now = clock.instant();
        s.setCreatedAt(now);
        s.setExpiresAt(now.plus(Duration.ofHours(ttlHours)));
        PostMedia m = null;
        if (req.mediaId() != null) {
            m = media.findById(req.mediaId()).orElse(null);
            if (m == null || !m.getOwnerId().equals(uid) || m.getPostId() != null || m.getStoryId() != null
                    || m.isHidden()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", "Seçilen medya geçersiz.");
            }
            if (m.isVideo() && (m.getDurationMs() == null || m.getDurationMs() > videoMaxSeconds * 1000L)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "STORY_VIDEO_TOO_LONG",
                        "Hikaye videosu en çok {0} saniye olabilir.", String.valueOf(videoMaxSeconds));
            }
            s.setKind(m.isVideo() ? Story.VIDEO : Story.IMAGE);
            s.setMediaId(m.getId());
            s.setCaption(caption);
        } else {
            if (text == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "STORY_EMPTY", "Hikaye için medya veya metin gerekli.");
            }
            String bg = req.background() == null || req.background().isBlank() ? DEFAULT_BG : req.background().strip();
            if (!COLOR.matcher(bg).matches()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "STORY_BACKGROUND_INVALID", "Geçersiz arka plan rengi.");
            }
            s.setKind(Story.TEXT);
            s.setBodyText(text);
            s.setCaption(caption);
            s.setBackground(bg.toUpperCase(java.util.Locale.ROOT));
        }
        s = stories.saveAndFlush(s);
        if (m != null && media.bindStory(m.getId(), uid, s.getId()) != 1) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", "Seçilen medya geçersiz.");
        }
        return views(uid, List.of(s)).get(0);
    }

    /** Sahibi ya da ADMIN; yumusak silme (medya temizlik isinde kalkar, erisim hemen kapanir). */
    @Transactional
    public void delete(Long actor, Long id, boolean admin) {
        Story s = stories.findById(id).filter(x -> x.getDeletedAt() == null).orElseThrow(StoryService::notFound);
        if (!admin && !s.getAuthorId().equals(actor)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "STORY_FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        s.setDeletedAt(clock.instant());
        stories.save(s);
    }

    // ---------------------------------------------------------------- okuma

    /** Kendim + takip ettiklerim; kendim ilk, sonra gorulmemisler, sonra en yeni. */
    @Transactional(readOnly = true)
    public List<TrayItem> tray(Long viewer) {
        Timestamp now = Timestamp.from(clock.instant());
        List<Object[]> rows = jdbc.query("SELECT s.author_id, COUNT(*), MAX(s.created_at), "
                + "SUM(CASE WHEN v.viewer_id IS NULL THEN 1 ELSE 0 END) FROM story s "
                + "LEFT JOIN story_view v ON v.story_id = s.id AND v.viewer_id = ? "
                + "WHERE s.deleted_at IS NULL AND s.hidden_at IS NULL AND s.expires_at > ? "
                + "AND (s.author_id = ? OR s.author_id IN (SELECT followee_id FROM user_follow WHERE follower_id = ?)) "
                + "AND EXISTS (SELECT 1 FROM app_user u WHERE u.id = s.author_id AND u.status = 'ACTIVE') "
                + "AND NOT EXISTS (SELECT 1 FROM user_block b WHERE (b.blocker_id = ? AND b.blocked_id = s.author_id) "
                + "OR (b.blocker_id = s.author_id AND b.blocked_id = ?)) "
                + "GROUP BY s.author_id ORDER BY MAX(s.created_at) DESC LIMIT " + TRAY_MAX,
                (rs, i) -> new Object[] {rs.getLong(1), rs.getInt(2), rs.getTimestamp(3).toInstant(), rs.getInt(4)},
                viewer, now, viewer, viewer, viewer, viewer);
        if (rows.isEmpty()) {
            return List.of();
        }
        Map<Long, AuthorView> authors = authors(viewer, rows.stream().map(r -> (Long) r[0]).toList());
        List<TrayItem> out = new ArrayList<>();
        for (Object[] r : rows) {
            Long author = (Long) r[0];
            AuthorView a = authors.get(author);
            if (a == null) {
                continue;
            }
            boolean mine = author.equals(viewer);
            out.add(new TrayItem(a, !mine && (Integer) r[3] > 0, (Instant) r[2], (Integer) r[1], mine));
        }
        out.sort(Comparator.comparing((TrayItem t) -> !t.mine()).thenComparing(t -> !t.hasUnseen())
                .thenComparing(TrayItem::latestAt, Comparator.reverseOrder()));
        return out;
    }

    @Transactional(readOnly = true)
    public List<StoryView> ofUser(Long viewer, Long authorId) {
        User a = users.findById(authorId).orElse(null);
        if (a == null || !a.isActive() || (!viewer.equals(authorId) && blocks.isBlocked(viewer, authorId))) {
            return List.of();
        }
        return views(viewer, stories.live(authorId, clock.instant()));
    }

    /** Idempotent; sahibinin kendi goruntulemesi sayilmaz. */
    @Transactional
    public void markViewed(Long viewer, Long id) {
        Story s = visible(viewer, id);
        if (s.getAuthorId().equals(viewer)) {
            return;
        }
        int n = jdbc.update("INSERT INTO story_view (story_id, viewer_id, viewed_at) SELECT ?, ?, CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM story_view WHERE story_id = ? AND viewer_id = ?)", id, viewer, id, viewer);
        if (n > 0) {
            jdbc.update("UPDATE story SET view_count = view_count + 1 WHERE id = ?", id);
        }
    }

    @Transactional(readOnly = true)
    public ViewerPage viewers(Long owner, Long id, String cursor, int size) {
        Story s = stories.findById(id).filter(x -> x.getDeletedAt() == null).orElseThrow(StoryService::notFound);
        if (!s.getAuthorId().equals(owner)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "STORY_FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        int n = size <= 0 ? 30 : Math.min(size, 30);
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<StorySeen> rows = c == null ? seen.first(id, PageRequest.of(0, n + 1))
                : seen.after(id, c.at(), c.id(), PageRequest.of(0, n + 1));
        boolean more = rows.size() > n;
        List<StorySeen> page = more ? rows.subList(0, n) : rows;
        Set<Long> hidden = blocks.hiddenFrom(owner);
        Map<Long, AuthorView> who = authors(owner, page.stream().map(v -> v.getId().getB()).toList());
        List<Viewer> items = new ArrayList<>();
        for (StorySeen v : page) {
            AuthorView a = who.get(v.getId().getB());
            if (a != null && !hidden.contains(a.id())) {
                items.add(new Viewer(a.id(), a.displayName(), a.avatarUrl(), v.getViewedAt()));
            }
        }
        String next = more ? PostCursor.latest(page.get(page.size() - 1).getViewedAt(),
                page.get(page.size() - 1).getId().getB()) : null;
        return new ViewerPage(items, next, s.getViewCount());
    }

    /** Baska modullerin (rapor, yonetici) gorunurluk karari: canli + engel yok. */
    @Transactional(readOnly = true)
    public Story visible(Long viewer, Long id) {
        Story s = stories.findById(id).orElseThrow(StoryService::notFound);
        if (!s.isLive(clock.instant())) {
            throw notFound();
        }
        User a = users.findById(s.getAuthorId()).orElse(null);
        if (a == null || !a.isActive() || (!viewer.equals(s.getAuthorId()) && blocks.isBlocked(viewer, s.getAuthorId()))) {
            throw notFound();
        }
        return s;
    }

    // ---------------------------------------------------------------- yardimcilar

    /** Toplu StoryView (yazar profili gizlilikle, medya, goruldu bilgisi). */
    List<StoryView> views(Long viewer, List<Story> list) {
        if (list.isEmpty()) {
            return List.of();
        }
        List<Long> ids = list.stream().map(Story::getId).toList();
        Map<Long, AuthorView> authors = authors(viewer, list.stream().map(Story::getAuthorId).distinct().toList());
        Map<Long, MediaView> mediaBy = new HashMap<>();
        media.findByStoryIdIn(ids).forEach(m -> mediaBy.put(m.getStoryId(), mediaView(m)));
        Set<Long> seenIds = new HashSet<>(seen.seenAmong(viewer, ids));
        List<StoryView> out = new ArrayList<>();
        for (Story s : list) {
            boolean mine = s.getAuthorId().equals(viewer);
            out.add(new StoryView(s.getId(), authors.get(s.getAuthorId()), s.getKind(), mediaBy.get(s.getId()),
                    s.getBodyText(), s.getCaption(), s.getBackground(), s.getCreatedAt(), s.getExpiresAt(),
                    mine || seenIds.contains(s.getId()), mine ? s.getViewCount() : null, mine));
        }
        return out;
    }

    private Map<Long, AuthorView> authors(Long viewer, java.util.Collection<Long> ids) {
        Map<Long, AuthorView> out = new HashMap<>();
        if (ids.isEmpty()) {
            return out;
        }
        for (PublicProfile p : profiles.mapAll(viewer, users.findAllById(new LinkedHashSet<>(ids)))) {
            out.put(p.id(), new AuthorView(p.id(), p.displayName(), p.avatarUrl()));
        }
        return out;
    }

    static MediaView mediaView(PostMedia m) {
        String url = "/api/posts/media/" + m.getId();
        return new MediaView(m.getId(), m.getKind(), url, url + "?thumb=true", m.getWidth(), m.getHeight(),
                m.getDurationMs());
    }

    private static String norm(String s) {
        if (s == null) {
            return null;
        }
        String t = s.strip();
        return t.isEmpty() ? null : t;
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "STORY_NOT_FOUND", "Hikaye bulunamadı.");
    }
}
