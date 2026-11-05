package edu.bingol.backend.forum.profile;

import com.fasterxml.jackson.annotation.JsonInclude;
import edu.bingol.backend.forum.profile.ForumProfileRepository.CommentRow;
import edu.bingol.backend.forum.profile.ForumProfileRepository.Cursor;
import edu.bingol.backend.forum.profile.ForumProfileRepository.Row;
import edu.bingol.backend.forum.profile.ForumProfileRepository.SavedRow;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.forum.topic.spi.ForumTopicSummaries;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.follow.PrivateAccountGate;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.charset.StandardCharsets;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Forum profil / etkinlik: kendi (anonim dahil) ve baskasinin (YALNIZ anonim olmayan) konu/yorum listeleri, kaydedilenler,
 * takip edilenler ve sayaclar. Kimlikler {@link ForumProfileRepository}'den, kartlar A'nin {@link ForumTopicSummaries}
 * ve B'nin {@link ForumProfileComments} gorunumlerinden gelir (gorunurluk kurali onlarda tek yerdedir).
 *
 * <p>Baskasinin profili kapilari: kullanici yok/pasif, engel iliskisi ya da sessize alma = BOS liste (var/yok
 * ayrimi yok, post modulundeki {@code byAuthor} ile ayni); gizli hesap ve bakan kabul edilmis takipci degil =
 * bos liste + {@code locked:true}.
 */
@Service
public class ForumProfileService {

    static final int DEFAULT_SIZE = 15;
    static final int MAX_SIZE = 30;

    /** Imecli sayfa; {@code locked} yalniz kilitli gizli hesapta true doner (aksi halde JSON'a yazilmaz). */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record ProfilePage<T>(List<T> items, String nextCursor, Boolean locked) {
        static <T> ProfilePage<T> of(List<T> items, String next) {
            return new ProfilePage<>(items, next, null);
        }

        static <T> ProfilePage<T> emptyPage() {
            return new ProfilePage<>(List.of(), null, null);
        }

        static <T> ProfilePage<T> lockedPage() {
            return new ProfilePage<>(List.of(), null, Boolean.TRUE);
        }
    }

    /**
     * Kaydedilen oge. {@code type=TOPIC}: {@code topic} dolu, {@code comment} null. {@code type=COMMENT}: {@code comment}
     * (B'nin CommentView alanlari DUZ + {@code topicTitle}) dolu, {@code topic} = yorumun bagli konusunun karti
     * (gorunmuyorsa oge hic dönmez).
     */
    @JsonInclude(JsonInclude.Include.ALWAYS)
    public record SavedItem(String type, Instant savedAt, TopicSummary topic, Map<String, Object> comment) {}

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Summary(long topicCount, long commentCount, Boolean locked) {}

    private enum Access { OPEN, EMPTY, LOCKED }

    private final ForumProfileRepository repo;
    private final ObjectProvider<ForumTopicSummaries> summaries;
    private final ObjectProvider<ForumProfileComments> commentViews;
    private final ObjectProvider<ForumMuteLookup> mutes;
    private final BlockService blocks;
    private final PrivateAccountGate gate;
    private final UserRepository users;
    private final JsonMapper json;

    public ForumProfileService(ForumProfileRepository repo, ObjectProvider<ForumTopicSummaries> summaries,
                               ObjectProvider<ForumProfileComments> commentViews, ObjectProvider<ForumMuteLookup> mutes,
                               BlockService blocks, PrivateAccountGate gate, UserRepository users, JsonMapper json) {
        this.repo = repo;
        this.summaries = summaries;
        this.commentViews = commentViews;
        this.mutes = mutes;
        this.blocks = blocks;
        this.gate = gate;
        this.users = users;
        this.json = json;
    }

    // ------------------------------------------------------------------ kendi

    @Transactional(readOnly = true)
    public ProfilePage<TopicSummary> myTopics(Long me, String cursor, Integer size) {
        return topicPage(me, cursor, size, (c, n) -> repo.topics(me, true, c, n));
    }

    @Transactional(readOnly = true)
    public ProfilePage<TopicSummary> following(Long me, String cursor, Integer size) {
        return topicPage(me, cursor, size, (c, n) -> repo.following(me, c, n));
    }

    @Transactional(readOnly = true)
    public ProfilePage<Map<String, Object>> myComments(Long me, String cursor, Integer size) {
        return commentPage(me, me, true, cursor, size);
    }

    @Transactional(readOnly = true)
    public ProfilePage<SavedItem> saved(Long me, String cursor, Integer size) {
        int n = clamp(size);
        Cursor cur = decode(cursor);
        List<SavedRow> rows = repo.saved(me, cur, n + 1);
        boolean more = rows.size() > n;
        List<SavedRow> page = more ? rows.subList(0, n) : rows;
        String next = more ? encode(page.get(page.size() - 1).at(), page.get(page.size() - 1).targetId()) : null;
        List<Long> topicIds = new ArrayList<>();
        List<Long> commentIds = new ArrayList<>();
        for (SavedRow r : page) {
            ("COMMENT".equals(r.type()) ? commentIds : topicIds).add(r.targetId());
        }
        Map<Long, ForumProfileRepository.CommentContext> ctx = Map.of();
        Map<Long, Object> views = Map.of();
        ForumProfileComments cv = commentViews.getIfAvailable();
        if (!commentIds.isEmpty() && cv != null) {
            views = cv.views(commentIds, me);
            ctx = repo.commentContext(views.keySet());
        }
        // konu kartlari: kaydedilen konular + kaydedilen yorumlarin bagli konulari (tek cagri)
        List<Long> allTopicIds = new ArrayList<>(topicIds);
        ctx.values().forEach(c -> allTopicIds.add(c.topicId()));
        Map<Long, TopicSummary> topics = new HashMap<>();
        if (!allTopicIds.isEmpty()) {
            summaries.getObject().summaries(allTopicIds.stream().distinct().toList(), me)
                    .forEach(s -> topics.put(s.id(), s));
        }
        List<SavedItem> items = new ArrayList<>();
        for (SavedRow r : page) {
            if ("COMMENT".equals(r.type())) {
                Object v = views.get(r.targetId());
                var c = ctx.get(r.targetId());
                TopicSummary t = c == null ? null : topics.get(c.topicId());
                if (v != null && t != null) {
                    items.add(new SavedItem("COMMENT", r.at(), t, flat(v, c.topicId(), c.title())));
                }
            } else {
                TopicSummary t = topics.get(r.targetId());
                if (t != null) {
                    items.add(new SavedItem("TOPIC", r.at(), t, null));
                }
            }
        }
        return ProfilePage.of(items, next);
    }

    // ------------------------------------------------------------------ baskasi

    @Transactional(readOnly = true)
    public ProfilePage<TopicSummary> userTopics(Long viewer, Long owner, String cursor, Integer size) {
        Access a = access(viewer, owner);
        if (a != Access.OPEN) {
            return a == Access.LOCKED ? ProfilePage.lockedPage() : ProfilePage.emptyPage();
        }
        return topicPage(viewer, cursor, size, (c, n) -> repo.topics(owner, false, c, n));
    }

    @Transactional(readOnly = true)
    public ProfilePage<Map<String, Object>> userComments(Long viewer, Long owner, String cursor, Integer size) {
        Access a = access(viewer, owner);
        if (a != Access.OPEN) {
            return a == Access.LOCKED ? ProfilePage.lockedPage() : ProfilePage.emptyPage();
        }
        return commentPage(viewer, owner, false, cursor, size);
    }

    @Transactional(readOnly = true)
    public Summary userSummary(Long viewer, Long owner) {
        Access a = access(viewer, owner);
        if (a == Access.LOCKED) {
            return new Summary(0, 0, Boolean.TRUE);
        }
        if (a == Access.EMPTY) {
            return new Summary(0, 0, null);
        }
        return new Summary(repo.publicTopicCount(owner), repo.publicCommentCount(owner), null);
    }

    // ------------------------------------------------------------------ ortak

    /** Baskasinin profili kapisi (anonim kimlik sizmasin diye var/yok ayrimi yok). */
    private Access access(Long viewer, Long owner) {
        User u = owner == null ? null : users.findById(owner).orElse(null);
        if (u == null || !u.isActive() || blocks.isBlocked(viewer, owner)) {
            return Access.EMPTY;
        }
        ForumMuteLookup m = mutes.getIfAvailable();
        if (m != null && m.mutedBy(viewer).contains(owner)) {
            return Access.EMPTY;
        }
        return gate.canSeeContent(viewer, owner) ? Access.OPEN : Access.LOCKED;
    }

    /** Anahtar kumesi okuyucu: (imlec, n) -> n satir. */
    @FunctionalInterface
    private interface RowSource {
        List<Row> fetch(Cursor cursor, int n);
    }

    private ProfilePage<TopicSummary> topicPage(Long viewer, String cursor, Integer size, RowSource source) {
        int n = clamp(size);
        List<Row> rows = source.fetch(decode(cursor), n + 1);
        boolean more = rows.size() > n;
        List<Row> page = more ? rows.subList(0, n) : rows;
        String next = more ? encode(page.get(page.size() - 1).at(), page.get(page.size() - 1).id()) : null;
        if (page.isEmpty()) {
            return ProfilePage.emptyPage();
        }
        List<TopicSummary> items = summaries.getObject().summaries(page.stream().map(Row::id).toList(), viewer);
        return ProfilePage.of(items, next);
    }

    private ProfilePage<Map<String, Object>> commentPage(Long viewer, Long owner, boolean includeAnonymous, String cursor,
                                                    Integer size) {
        int n = clamp(size);
        List<CommentRow> rows = repo.comments(owner, includeAnonymous, decode(cursor), n + 1);
        boolean more = rows.size() > n;
        List<CommentRow> page = more ? rows.subList(0, n) : rows;
        String next = more ? encode(page.get(page.size() - 1).at(), page.get(page.size() - 1).id()) : null;
        if (page.isEmpty()) {
            return ProfilePage.emptyPage();
        }
        ForumProfileComments cv = commentViews.getIfAvailable();
        Map<Long, Object> views = cv == null ? Map.of() : cv.views(page.stream().map(CommentRow::id).toList(), viewer);
        List<Map<String, Object>> items = new ArrayList<>();
        for (CommentRow r : page) {
            Object v = views.get(r.id());
            if (v != null) {
                items.add(flat(v, r.topicId(), r.topicTitle()));
            }
        }
        return ProfilePage.of(items, next);
    }

    private static final TypeReference<Map<String, Object>> MAP = new TypeReference<>() {};

    /** B'nin CommentView'ini DUZ haritaya cevirir ve {@code topicId} + {@code topicTitle} ekler (istemci tek nesne okur). */
    private Map<String, Object> flat(Object view, long topicId, String topicTitle) {
        Map<String, Object> m = new LinkedHashMap<>(json.convertValue(view, MAP));
        m.putIfAbsent("topicId", topicId);
        m.put("topicTitle", topicTitle);
        return m;
    }

    static int clamp(Integer size) {
        return size == null || size <= 0 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
    }

    // ------------------------------------------------------------------ imlec

    /** Opak imlec: "saniye.nano_kimlik" (base64url). */
    static String encode(Instant at, long id) {
        String raw = at.getEpochSecond() + "." + at.getNano() + "_" + id;
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    /** Bozuk/bos imlec = ilk sayfa. */
    static Cursor decode(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
            int us = raw.indexOf('_');
            int dot = raw.indexOf('.');
            if (us < 0 || dot < 0 || dot > us) {
                return null;
            }
            long sec = Long.parseLong(raw.substring(0, dot));
            int nano = Integer.parseInt(raw.substring(dot + 1, us));
            long id = Long.parseLong(raw.substring(us + 1));
            return new Cursor(Instant.ofEpochSecond(sec, nano), id);
        } catch (RuntimeException e) {
            return null;
        }
    }
}
