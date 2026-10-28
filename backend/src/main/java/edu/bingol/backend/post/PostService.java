package edu.bingol.backend.post;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.spi.PostMediaBinder;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.function.Function;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Genel gönderi iş kuralları. Beğeni (C), yorum (D), medya (B) kendi paketlerinde; sayaçlar PostCounters ile. */
@Service
public class PostService {

    public static final Duration POPULAR_WINDOW = Duration.ofDays(7);

    private final PostRepository posts;
    private final UserRepository users;
    private final UserBlockRepository blocks;
    private final PostViewAssembler assembler;
    private final ContentGuard guard;
    private final ObjectProvider<PostMediaBinder> binders;
    private final ApplicationEventPublisher events;

    /** Takip/bolum akis sorgulari (post.social); setter: kurucu imzasi degismesin. */
    private ObjectProvider<edu.bingol.backend.post.social.SocialFeedRepository> socialFeeds;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setSocialFeeds(ObjectProvider<edu.bingol.backend.post.social.SocialFeedRepository> socialFeeds) {
        this.socialFeeds = socialFeeds;
    }

    /** Kesfet top puani/siralamasi (setter: kurucu imzasi degismesin). */
    private PostRankService rank;
    private PostRankRepository rankRepo;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setRank(PostRankService rank, PostRankRepository rankRepo) {
        this.rank = rank;
        this.rankRepo = rankRepo;
    }

    public PostService(PostRepository posts, UserRepository users, UserBlockRepository blocks,
                       PostViewAssembler assembler, ContentGuard guard, ObjectProvider<PostMediaBinder> binders,
                       ApplicationEventPublisher events) {
        this.posts = posts;
        this.users = users;
        this.blocks = blocks;
        this.assembler = assembler;
        this.guard = guard;
        this.binders = binders;
        this.events = events;
    }

    /** Sade gonderi: tam 1 fotograf (zorunlu) + en cok 7 kelimelik, istege bagli tek satir metin. */
    @Transactional
    public PostView create(Long uid, CreatePostRequest req) {
        String text = normalize(req.text());
        List<Long> mediaIds = req.mediaIds() == null ? List.of() : req.mediaIds().stream().distinct().toList();
        int requested = req.mediaIds() == null ? 0 : req.mediaIds().size();
        if (mediaIds.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_PHOTO_REQUIRED", "Gönderi için bir fotoğraf gerekli.");
        }
        if (mediaIds.size() > 1 || requested > 1) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_SINGLE_PHOTO_ONLY",
                    "Gönderiye yalnızca tek bir fotoğraf eklenebilir.");
        }
        checkText(text);
        guard.assertClean(ContentGuard.Entity.POST, "text", uid, text);
        PostMediaBinder binder = binders.getIfAvailable();
        if (binder == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", "Seçilen medya geçersiz.");
        }
        binder.requireImage(uid, mediaIds); // video/yabancı/geçersiz medya: gönderi kaydedilmeden reddedilir
        Post p = new Post();
        p.setAuthorId(uid);
        p.setBody(text);
        if (rank != null) {
            p.setRankScore(rank.initialScore(p)); // soguk baslangic: yeni gonderi hemen gorunur
        }
        p = posts.saveAndFlush(p);
        binder.attach(p.getId(), uid, mediaIds);
        p.setMediaCount((short) mediaIds.size());
        p = posts.saveAndFlush(p);
        // Etiket/bahsetme kaldirildi: SocialTextEvent artik yayinlanmaz
        return assembler.assemble(uid, p);
    }

    @Transactional(readOnly = true)
    public PostView get(Long viewer, Long id) {
        return assembler.assemble(viewer, requireVisible(id, viewer));
    }

    @Transactional
    public PostView update(Long uid, Long id, String rawText) {
        Post p = requireVisible(id, uid);
        if (!p.getAuthorId().equals(uid)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "POST_FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        String text = normalize(rawText);
        if (text == null && p.getMediaCount() == 0) { // yalniz fotografsiz eski gonderiler
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_EMPTY", "Gönderi için metin veya medya gerekli.");
        }
        checkText(text);
        guard.assertChanged(ContentGuard.Entity.POST, "text", uid, p.getBody(), text);
        p.setBody(text);
        p.setEditedAt(Instant.now());
        Post saved = posts.saveAndFlush(p);
        return assembler.assemble(uid, saved);
    }

    /** Yazar ya da ADMIN siler (yumuşak); medya temizliği PostDeletedEvent ile B'ye bildirilir. */
    @Transactional
    public void delete(Long actorId, Long id, boolean admin) {
        Post p = posts.findById(id).filter(x -> x.getDeletedAt() == null).orElseThrow(PostService::notFound);
        if (!admin && !p.getAuthorId().equals(actorId)) {
            // başkasının gönderisini görebiliyorsa 403, göremiyorsa (gizli) 404
            requireVisible(id, actorId);
            throw new ApiException(HttpStatus.FORBIDDEN, "POST_FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        p.setDeletedAt(Instant.now());
        p.setDeletedBy(actorId);
        posts.save(p);
        PostMediaBinder binder = binders.getIfAvailable();
        events.publishEvent(new PostDeletedEvent(p.getId(), binder == null ? List.of() : binder.mediaIdsOf(p.getId())));
    }

    @Transactional(readOnly = true)
    public FeedPage feed(Long viewer, String scope, String cursor, int size) {
        int n = clamp(size);
        if ("following".equalsIgnoreCase(scope) || "department".equalsIgnoreCase(scope)) {
            return socialFeed(viewer, scope.toLowerCase(java.util.Locale.ROOT), cursor, n);
        }
        if ("top".equalsIgnoreCase(scope) && rank != null) {
            return topFeed(viewer, cursor, size);
        }
        if (scope != null && !scope.isBlank() && !"latest".equalsIgnoreCase(scope) && !"popular".equalsIgnoreCase(scope)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FEED_SCOPE_INVALID", "Geçersiz akış türü.");
        }
        if ("popular".equalsIgnoreCase(scope)) {
            Instant since = Instant.now().minus(POPULAR_WINDOW);
            PostCursor c = PostCursor.decode(cursor, 'P');
            List<Post> rows = c == null
                    ? posts.popularFirst(viewer, since, PageRequest.of(0, n + 1))
                    : posts.popularAfter(viewer, since, c.score(), c.id(), PageRequest.of(0, n + 1));
            return page(viewer, rows, n, p -> PostCursor.popular(p.getScore(), p.getId()));
        }
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<Post> rows = c == null
                ? posts.latestFirst(viewer, PageRequest.of(0, n + 1))
                : posts.latestAfter(viewer, c.at(), c.id(), PageRequest.of(0, n + 1));
        return page(viewer, rows, n, p -> PostCursor.latest(p.getCreatedAt(), p.getId()));
    }

    /**
     * top: onceden hesaplanmis rank_score'a gore (rank_score DESC, id DESC) imecli sayfa. Varsayilan 12, ust sinir 30.
     * Puan istemciye donmez. Sayfa icinde ayni yazar ardisik en cok maxAuthorRun (kayipsiz yeniden siralama).
     * Imlec yeniden hesap sonrasi eskiyse hint=RANK_REFRESHED (nadir kopya olabilir; istemci id ile ayiklar).
     */
    private FeedPage topFeed(Long viewer, String cursor, int size) {
        PostRankProperties cfg = rank.props();
        int n = size <= 0 ? cfg.defaultPageSize() : Math.min(size, cfg.maxPageSize());
        PostCursor.Top c = PostCursor.decodeTop(cursor);
        List<Post> rows = c == null
                ? rankRepo.topFirst(viewer, PageRequest.of(0, n + 1))
                : rankRepo.topAfter(viewer, c.score(), c.id(), PageRequest.of(0, n + 1));
        boolean more = rows.size() > n;
        List<Post> items = more ? rows.subList(0, n) : rows;
        String next = null;
        if (more) {
            Post last = items.get(items.size() - 1);
            next = PostCursor.top(last.getRankScore(), last.getId(), rank.version());
        }
        String hint = c != null && c.version() != rank.version() ? "RANK_REFRESHED" : null;
        List<Post> shown = PostRank.diversify(items, Post::getAuthorId, cfg.maxAuthorRun());
        return new FeedPage(assembler.assemble(viewer, shown), next, hint);
    }

    /** following | department kapsamları (post.social sorguları). */
    private FeedPage socialFeed(Long viewer, String scope, String cursor, int n) {
        edu.bingol.backend.post.social.SocialFeedRepository repo = socialFeeds == null ? null : socialFeeds.getIfAvailable();
        if (repo == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FEED_SCOPE_INVALID", "Geçersiz akış türü.");
        }
        PostCursor c = PostCursor.decode(cursor, 'L');
        Instant at = c == null ? null : c.at();
        long cid = c == null ? 0 : c.id();
        List<Post> rows;
        if ("following".equals(scope)) {
            rows = c == null ? repo.followingFirst(viewer, PageRequest.of(0, n + 1))
                    : repo.followingAfter(viewer, at, cid, PageRequest.of(0, n + 1));
        } else {
            String dept = users.findById(viewer).map(u -> u.getDepartment()).filter(d -> d != null && !d.isBlank())
                    .orElse(null);
            if (dept == null) {
                return new FeedPage(List.of(), null, "NO_DEPARTMENT");
            }
            rows = c == null ? repo.departmentFirst(viewer, dept, PageRequest.of(0, n + 1))
                    : repo.departmentAfter(viewer, dept, at, cid, PageRequest.of(0, n + 1));
        }
        return page(viewer, rows, n, p -> PostCursor.latest(p.getCreatedAt(), p.getId()));
    }

    /** Bir kullanıcının gönderileri (engel ilişkisinde / pasif yazarda boş). */
    @Transactional(readOnly = true)
    public FeedPage byAuthor(Long viewer, Long authorId, String cursor, int size) {
        int n = clamp(size);
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<Post> rows = c == null
                ? posts.byAuthorFirst(authorId, viewer, PageRequest.of(0, n + 1))
                : posts.byAuthorAfter(authorId, viewer, c.at(), c.id(), PageRequest.of(0, n + 1));
        return page(viewer, rows, n, p -> PostCursor.latest(p.getCreatedAt(), p.getId()));
    }

    /** Diğer modüllerin (beğeni, yorum, rapor) kullanacağı: görünür değilse 404. */
    @Transactional(readOnly = true)
    public Post requireVisible(Long id, Long viewer) {
        Post p = posts.findById(id).orElseThrow(PostService::notFound);
        if (!p.isVisible()) {
            throw notFound();
        }
        boolean authorActive = users.findById(p.getAuthorId())
                .map(u -> u.getStatus() == UserStatus.ACTIVE).orElse(false);
        if (!authorActive || (!p.getAuthorId().equals(viewer) && blocks.existsBetween(viewer, p.getAuthorId()))) {
            throw notFound();
        }
        return p;
    }

    private FeedPage page(Long viewer, List<Post> rows, int n, Function<Post, String> cursorOf) {
        boolean more = rows.size() > n;
        List<Post> items = more ? rows.subList(0, n) : rows;
        String next = more ? cursorOf.apply(items.get(items.size() - 1)) : null;
        return new FeedPage(assembler.assemble(viewer, items), next);
    }

    private static int clamp(int size) {
        return size <= 0 ? 10 : Math.min(size, 20);
    }

    private static String normalize(String s) {
        if (s == null) {
            return null;
        }
        String t = s.replaceAll("^[\\s\\p{Z}]+|[\\s\\p{Z}]+$", "");
        return t.isEmpty() ? null : t;
    }

    /**
     * Sade metin kurali: tek satir, en cok {@link PostDtos#MAX_WORDS} kelime (Unicode bosluga gore) ve
     * {@link PostDtos#MAX_CHARS} karakter (kod noktasi). Bos metin serbest.
     */
    static void checkText(String text) {
        if (text == null) {
            return;
        }
        if (text.codePoints().anyMatch(c -> c == '\n' || c == '\r' || c == 0x0B || c == 0x0C || c == 0x85
                || c == 0x2028 || c == 0x2029)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "POST_TEXT_INVALID",
                    "Gönderi metni tek satır olmalıdır.");
        }
        int words = text.split("[\\s\\p{Z}]+").length;
        if (words > PostDtos.MAX_WORDS || text.codePointCount(0, text.length()) > PostDtos.MAX_CHARS) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "POST_TEXT_TOO_LONG",
                    "Gönderi metni en çok 7 kelime ve 60 karakter olabilir.", String.valueOf(PostDtos.MAX_WORDS),
                    String.valueOf(PostDtos.MAX_CHARS));
        }
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
    }
}
