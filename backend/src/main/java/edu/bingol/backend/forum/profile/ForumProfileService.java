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
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Collection;
import java.util.HashMap;
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

    /** Profil yorum satiri: B'nin CommentView'i + bagli konu. */
    public record ProfileComment(Object comment, long topicId, String topicTitle) {}

    /** Kaydedilen oge: kind=TOPIC ise {@code topic}, kind=COMMENT ise {@code comment} dolu. */
    @JsonInclude(JsonInclude.Include.ALWAYS)
    public record SavedItem(String kind, Instant savedAt, TopicSummary topic, ProfileComment comment) {}

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

    public ForumProfileService(ForumProfileRepository repo, ObjectProvider<ForumTopicSummaries> summaries,
                               ObjectProvider<ForumProfileComments> commentViews, ObjectProvider<ForumMuteLookup> mutes,
                               BlockService blocks, PrivateAccountGate gate, UserRepository users) {
        this.repo = repo;
        this.summaries = summaries;
        this.commentViews = commentViews;
        this.mutes = mutes;
        this.blocks = blocks;
        this.gate = gate;
        this.users = users;
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
    public ProfilePage<ProfileComment> myComments(Long me, String cursor, Integer size) {
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
        Map<Long, TopicSummary> topics = new HashMap<>();
        if (!topicIds.isEmpty()) {
            summaries.getObject().summaries(topicIds, me).forEach(s -> topics.put(s.id(), s));
        }
        Map<Long, ProfileComment> comments = commentIds.isEmpty() ? Map.of() : profileComments(me, commentIds);
        List<SavedItem> items = new ArrayList<>();
        for (SavedRow r : page) {
            if ("COMMENT".equals(r.type())) {
                ProfileComment c = comments.get(r.targetId());
                if (c != null) {
                    items.add(new SavedItem("COMMENT", r.at(), null, c));
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
    public ProfilePage<ProfileComment> userComments(Long viewer, Long owner, String cursor, Integer size) {
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

    private ProfilePage<ProfileComment> commentPage(Long viewer, Long owner, boolean includeAnonymous, String cursor,
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
        List<ProfileComment> items = new ArrayList<>();
        for (CommentRow r : page) {
            Object v = views.get(r.id());
            if (v != null) {
                items.add(new ProfileComment(v, r.topicId(), r.topicTitle()));
            }
        }
        return ProfilePage.of(items, next);
    }

    /** Yorum kimliklerinden (kaydedilenler) bagli konu bilgisiyle profil yorumlari; gorunmeyen yorum yoktur. */
    private Map<Long, ProfileComment> profileComments(Long viewer, Collection<Long> commentIds) {
        ForumProfileComments cv = commentViews.getIfAvailable();
        if (cv == null) {
            return Map.of();
        }
        Map<Long, Object> views = cv.views(commentIds, viewer);
        Map<Long, ProfileComment> out = new HashMap<>();
        repo.commentContext(views.keySet()).forEach((id, ctx) -> out.put(id,
                new ProfileComment(views.get(id), ctx.topicId(), ctx.title())));
        return out;
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
