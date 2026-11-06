package edu.bingol.backend.post;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.feed.FeedSeenService;
import edu.bingol.backend.post.feed.FeedSeenStore;
import edu.bingol.backend.post.reels.ReelsService;
import edu.bingol.backend.post.spi.PostMediaBinder;
import edu.bingol.backend.post.spi.PostMediaLookup;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
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
    /** Izlenme sayilmasi icin en az izleme suresi (video bundan kisaysa videonun tamami). */
    static final long MIN_VIEW_MS = 1000;

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

    /** Gorulmus kumesi (tekrar gostermeme) + izlenme sayaci + video suresi (setter: kurucu imzasi degismesin). */
    private FeedSeenService seen;
    private ReelsService reelsService;
    private PostCounters counters;
    private ObjectProvider<PostMediaLookup> mediaLookups;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setSeen(FeedSeenService seen) {
        this.seen = seen;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setReelsService(ReelsService reelsService) {
        this.reelsService = reelsService;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setCounters(PostCounters counters) {
        this.counters = counters;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMediaLookups(ObjectProvider<PostMediaLookup> mediaLookups) {
        this.mediaLookups = mediaLookups;
    }

    /** Gizli hesap kapisi (setter: kurucu imzasi degismesin; yoksa tum hesaplar herkese acik sayilir). */
    private edu.bingol.backend.post.follow.PrivateAccountGate gate;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setGate(edu.bingol.backend.post.follow.PrivateAccountGate gate) {
        this.gate = gate;
    }

    /** Etiketleme (V1310) ve bildirimi (setter: kurucu imzasi degismesin; yoksa etiket istekleri yok sayilir). */
    private edu.bingol.backend.post.mention.PostMentionService mentionService;
    private edu.bingol.backend.post.notify.PostNotifier mentionNotifier;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMentions(edu.bingol.backend.post.mention.PostMentionService mentionService,
                     edu.bingol.backend.post.notify.PostNotifier mentionNotifier) {
        this.mentionService = mentionService;
        this.mentionNotifier = mentionNotifier;
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

    /** Gonderi: tam 1 medya (fotograf ya da video, zorunlu) + istege bagli metin (gizli ust sinir) + istege bagli etiketler. */
    @Transactional
    public PostView create(Long uid, CreatePostRequest req) {
        return create(uid, req, null);
    }

    /** Idempotency-Key bicimi: 8-64 karakter, harf/rakam/tire/alt cizgi. */
    static String cleanKey(String key) {
        if (key == null || key.isBlank()) {
            return null;
        }
        String k = key.trim();
        if (!k.matches("[A-Za-z0-9_-]{8,64}")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "IDEMPOTENCY_KEY_INVALID", "Geçersiz Idempotency-Key.");
        }
        return k;
    }

    /** Ayni anahtarla daha once olusan gonderi (yoksa null); silinmisse anahtar yeniden kullanilamaz (422). */
    @Transactional(readOnly = true)
    public PostView replayByKey(Long uid, String rawKey) {
        String key = cleanKey(rawKey);
        if (key == null) {
            return null;
        }
        Post p = posts.findFirstByAuthorIdAndIdempotencyKey(uid, key).orElse(null);
        if (p == null) {
            return null;
        }
        if (p.getDeletedAt() != null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "IDEMPOTENCY_KEY_REUSED",
                    "Bu Idempotency-Key başka bir istek için kullanılmış.");
        }
        return assembler.assemble(uid, p);
    }

    @Transactional
    public PostView create(Long uid, CreatePostRequest req, String rawKey) {
        String idemKey = cleanKey(rawKey);
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
        List<Long> mentionIds = mentionService == null ? null
                : mentionService.validate(uid, req.mentionUserIds(), List.of());
        PostMediaBinder binder = binders.getIfAvailable();
        if (binder == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", "Seçilen medya geçersiz.");
        }
        String kind = binder.requireMedia(uid, mediaIds); // yabancı/geçersiz medya: gönderi kaydedilmeden reddedilir
        Post p = new Post();
        p.setAuthorId(uid);
        p.setBody(text);
        p.setIdempotencyKey(idemKey);
        p.setKind("VIDEO".equals(kind) ? Post.KIND_VIDEO : Post.KIND_PHOTO);
        if (rank != null) {
            p.setRankScore(rank.initialScore(p)); // soguk baslangic: yeni gonderi hemen gorunur
        }
        p = posts.saveAndFlush(p);
        binder.attach(p.getId(), uid, mediaIds);
        p.setMediaCount((short) mediaIds.size());
        p = posts.saveAndFlush(p);
        applyMentions(uid, p.getId(), mentionIds);
        return assembler.assemble(uid, p);
    }

    /** Etiket listesini yazar ve YENI etiketlenenlere bildirim gonderir (hata gonderiyi bozmaz; bildirim en iyi caba). */
    private void applyMentions(Long authorId, Long postId, List<Long> mentionIds) {
        if (mentionService == null || mentionIds == null) {
            return;
        }
        List<Long> added = mentionService.replace(postId, mentionIds);
        if (mentionNotifier != null) {
            for (Long target : added) {
                mentionNotifier.onMention(authorId, postId, target);
            }
        }
    }

    @Transactional(readOnly = true)
    public PostView get(Long viewer, Long id) {
        return assembler.assemble(viewer, requireVisible(id, viewer));
    }

    @Transactional
    public PostView update(Long uid, Long id, String rawText) {
        return update(uid, id, rawText, null);
    }

    /**
     * Metin duzenleme + etiketler. mentionUserIds null: etiketler degismez (eski istemci); dolu (bos dahil): liste
     * yeniden yazilir, yalniz YENI eklenenlere bildirim gider.
     */
    @Transactional
    public PostView update(Long uid, Long id, String rawText, List<Long> mentionUserIds) {
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
        List<Long> mentionIds = mentionService == null ? null
                : mentionService.validate(uid, mentionUserIds, mentionService.idsOf(p.getId()));
        p.setBody(text);
        p.setEditedAt(Instant.now());
        Post saved = posts.saveAndFlush(p);
        applyMentions(uid, saved.getId(), mentionIds);
        return assembler.assemble(uid, saved);
    }

    /**
     * Yonetici metin duzenlemesi (AdminPostService cagirir). Silinmis gonderi 404; gizli gonderi duzenlenebilir.
     * Bicim kurali (gizli ust sinir: 2200 karakter / 40 satir) uygulanir; ContentGuard (kufur suzgeci) bilincli olarak ATLANIR:
     * yonetici ihlalli metni temizlemek icin duzenler, islem denetim kaydina (AuditInterceptor) yazilir. Bos metin
     * fotografli gonderide serbesttir (metin temizlenir).
     * @return gonderi yazarinin kimligi (bildirim icin)
     */
    @Transactional
    public Long adminEdit(Long id, String rawText) {
        Post p = posts.findById(id).filter(x -> x.getDeletedAt() == null).orElseThrow(PostService::notFound);
        String text = normalize(rawText);
        if (text == null && p.getMediaCount() == 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_EMPTY", "Gönderi için metin veya medya gerekli.");
        }
        checkText(text);
        p.setBody(text);
        p.setEditedAt(Instant.now());
        posts.saveAndFlush(p);
        return p.getAuthorId();
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
        if ("foryou".equalsIgnoreCase(scope) && rank != null) {
            return forYouFeed(viewer, cursor, size);
        }
        if (("popular".equalsIgnoreCase(scope) || "top".equalsIgnoreCase(scope)) && rank != null) {
            return rankedFeed(viewer, cursor, size, false); // popularite puani sirasi (tek puan altyapisi)
        }
        if ("foryou".equalsIgnoreCase(scope)) {
            scope = "latest"; // puan altyapisi yoksa (yalniz test/elle kurulum) kronolojik akisa dus
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
     * Keşfet (tek sıralama) ve Reels: önceden hesaplanmış rank_score'a göre (rank_score DESC, id DESC) imeçli sayfa.
     * Varsayılan 12 (reels 8), üst sınır 30 (reels 20). Puan istemciye dönmez. Sayfa içinde aynı yazar ardışık en çok
     * maxAuthorRun (kayıpsız yeniden sıralama). İmleç yeniden hesap sonrası eskiyse hint=RANK_REFRESHED.
     *
     * <p>Tekrar göstermeme: kullanıcının görülmüş kümesi (Redis feedseen) akıştan hariç tutulur; dönen sayfa da
     * görülmüş sayılır. İlk sayfada (imleç yok) hariç tutma sonucu boş kalır ve küme boş değilse havuz tükenmiştir:
     * en eski görülmüşlerden başlayıp tekrar eder, exhausted=true (boş akış yok).
     */
    private FeedPage rankedFeed(Long viewer, String cursor, int size, boolean reels) {
        PostRankProperties cfg = rank.props();
        int n = size <= 0 ? cfg.defaultPageSize() : Math.min(size, cfg.maxPageSize());
        PostCursor.Recycle rc = PostCursor.decodeRecycle(cursor);
        if (rc != null) {
            return recycledPage(viewer, rc.after(), rc.t0(), n, reels);
        }
        PostCursor.Top c = PostCursor.decodeTop(cursor);
        Set<Long> seenIds = seen == null ? Set.of() : seen.ids(viewer);
        Collection<Long> excl = seenIds.isEmpty() ? List.of(-1L) : seenIds;
        PageRequest pr = PageRequest.of(0, n + 1);
        List<Post> rows;
        if (c == null) {
            rows = reels ? rankRepo.reelsFirst(viewer, excl, pr) : rankRepo.topFirst(viewer, excl, pr);
        } else {
            rows = reels ? rankRepo.reelsAfter(viewer, excl, c.score(), c.id(), pr)
                    : rankRepo.topAfter(viewer, excl, c.score(), c.id(), pr);
        }
        if (c == null && rows.isEmpty() && !seenIds.isEmpty()) {
            return recycledPage(viewer, 0L, FeedSeenService.stamp(System.currentTimeMillis()), n, reels);
        }
        boolean more = rows.size() > n;
        List<Post> items = more ? rows.subList(0, n) : rows;
        String next = null;
        if (more) {
            Post last = items.get(items.size() - 1);
            next = PostCursor.top(last.getRankScore(), last.getId(), rank.version());
        }
        String hint = c != null && c.version() != rank.version() ? "RANK_REFRESHED" : null;
        List<Post> shown = PostRank.diversify(items, Post::getAuthorId, cfg.maxAuthorRun());
        if (seen != null) {
            seen.mark(viewer, shown.stream().map(Post::getId).toList());
        }
        return new FeedPage(assembler.assemble(viewer, shown), next, hint).withExhausted(false);
    }

    /** Reels: yalnız video gönderiler (aynı puan + görülmüş hariç tutma; görülmüş kümesi Keşfet ile ortaktır). */
    @Transactional(readOnly = true)
    public FeedPage reels(Long viewer, String cursor, int size, boolean replay) {
        if (reelsService == null) {
            return new FeedPage(List.of(), null, null).withExhausted(true);
        }
        return reelsService.reels(viewer, cursor, size, replay);
    }

    /**
     * "Senin Icin": ortak puanli havuzdan (gorulmus haric) takip + yazar ilgisi + populerlik + kontrollu rastgelelikle
     * yeniden siralanmis tek akis. Imlec yalniz oturum tohumunu tasir (gorulen sayfa gorulmus sayilip havuzdan
     * dustugu icin sonraki sayfa yeniden hesaplanir). Havuz tukenince en eski gorulmuslerden tekrar + exhausted=true.
     */
    private FeedPage forYouFeed(Long viewer, String cursor, int size) {
        PostRankProperties cfg = rank.props();
        int n = size <= 0 ? cfg.defaultPageSize() : Math.min(size, cfg.maxPageSize());
        PostCursor.Recycle rc = PostCursor.decodeRecycle(cursor);
        if (rc != null) {
            return recycledPage(viewer, rc.after(), rc.t0(), n, false);
        }
        PostCursor.ForYou fc = PostCursor.decodeForYou(cursor);
        long seed = fc != null ? fc.seed() : java.util.concurrent.ThreadLocalRandom.current().nextLong();
        Set<Long> seenIds = seen == null ? Set.of() : seen.ids(viewer);
        Collection<Long> excl = seenIds.isEmpty() ? List.of(-1L) : seenIds;
        int pool = reelsService == null ? n + 1 : Math.max(reelsService.props().forYouPoolSize(), n + 1);
        List<Post> rows = rankRepo.topFirst(viewer, excl, PageRequest.of(0, pool));
        if (fc == null && rows.isEmpty() && !seenIds.isEmpty()) {
            return recycledPage(viewer, 0L, FeedSeenService.stamp(System.currentTimeMillis()), n, false);
        }
        List<Post> ordered = reelsService == null ? rows : reelsService.orderForYou(viewer, rows, seed);
        ordered = PostRank.diversify(ordered, Post::getAuthorId, cfg.maxAuthorRun());
        boolean more = ordered.size() > n;
        List<Post> items = more ? ordered.subList(0, n) : ordered;
        if (seen != null) {
            seen.mark(viewer, items.stream().map(Post::getId).toList());
        }
        return new FeedPage(assembler.assemble(viewer, items), more ? PostCursor.forYou(seed) : null, null)
                .withExhausted(false);
    }

    /**
     * Tekrar modu: görülme damgası (after, t0) aralığındaki en eski görülmüşler, bakana hâlâ görünür olanlar. Döndürülen
     * gönderiler yeni damga alır (>= t0) ve aynı gezintide yeniden gelmez; imleç t0 ile sabit kalır.
     */
    private FeedPage recycledPage(Long viewer, long after, long t0, int n, boolean reels) {
        List<Post> picked = new ArrayList<>();
        List<Long> stamps = new ArrayList<>();
        long cursorAfter = after;
        int limit = (n + 1) * 2;
        for (int round = 0; round < 10 && picked.size() <= n; round++) {
            List<FeedSeenStore.Entry> batch = seen == null ? List.of() : seen.range(viewer, cursorAfter, t0, limit);
            if (batch.isEmpty()) {
                break;
            }
            List<Long> ids = batch.stream().map(FeedSeenStore.Entry::postId).toList();
            Map<Long, Post> visible = new HashMap<>();
            (reels ? rankRepo.visibleVideosByIds(viewer, ids) : rankRepo.visibleByIds(viewer, ids))
                    .forEach(p -> visible.put(p.getId(), p));
            for (FeedSeenStore.Entry e : batch) {
                cursorAfter = e.stamp();
                Post p = visible.get(e.postId());
                if (p != null && picked.size() <= n) {
                    picked.add(p);
                    stamps.add(e.stamp());
                }
            }
            if (batch.size() < limit) {
                break;
            }
        }
        boolean more = picked.size() > n;
        List<Post> items = more ? picked.subList(0, n) : picked;
        String next = more ? PostCursor.recycle(stamps.get(n - 1), t0) : null;
        if (seen != null && !items.isEmpty()) {
            seen.mark(viewer, items.stream().map(Post::getId).toList());
        }
        return new FeedPage(assembler.assemble(viewer, items), next, null).withExhausted(true);
    }

    /** POST /api/feed/seen: istemcinin görünen gönderi/reel kimlikleri (yedek bildirim; sunucu zaten döndürdüğünü işaretler). */
    public void markSeen(Long viewer, List<Long> ids) {
        if (seen == null || ids == null) {
            return;
        }
        List<Long> clean = ids.stream().filter(Objects::nonNull).filter(i -> i > 0).distinct().limit(100).toList();
        seen.mark(viewer, clean);
        if (reelsService != null) {
            reelsService.recordImpressions(viewer, clean); // video gosterimleri izleme gecmisine (hata sizmaz)
        }
    }

    /**
     * Video izlenme olayı: yalnız başkasının görünür VIDEO gönderisi; kullanıcı başına gönderi başına
     * viewDedupeHours (6 sa) içinde bir kez sayılır; en az min(1 sn, süre) izlenmiş olmalı. Süre sunucudaki video
     * süresidir (istemcininki yalnız yedek). Döner: sayıldı mı.
     */
    @Transactional
    public boolean recordView(Long viewer, Long id, long watchedMs, long clientDurationMs) {
        Post p = requireVisible(id, viewer);
        if (!p.isVideo() || p.getAuthorId().equals(viewer) || counters == null || seen == null) {
            return false;
        }
        long dur = serverDurationMs(viewer, id);
        if (dur <= 0) {
            dur = clientDurationMs;
        }
        if (dur <= 0 || watchedMs < Math.min(MIN_VIEW_MS, dur)) {
            return false;
        }
        if (!seen.claimView(viewer, id)) {
            return false;
        }
        int pct = (int) Math.max(0, Math.min(100, watchedMs * 100 / dur));
        counters.addView(id, pct);
        return true;
    }

    private long serverDurationMs(Long viewer, Long postId) {
        if (mediaLookups == null) {
            return 0;
        }
        try {
            for (PostMediaLookup l : mediaLookups.orderedStream().toList()) {
                List<PostDtos.MediaView> v = l.viewsFor(List.of(postId), viewer).get(postId);
                if (v != null && !v.isEmpty() && v.get(0).durationMs() != null) {
                    return v.get(0).durationMs();
                }
            }
        } catch (RuntimeException e) {
            return 0;
        }
        return 0;
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
            // T-070: acik yazar listesi (kendisi + takip ettikleri) -> yazar indeksi; EXISTS/OR yerine
            java.util.LinkedHashSet<Long> authors = new java.util.LinkedHashSet<>();
            authors.add(viewer);
            authors.addAll(repo.followeeIds(viewer,
                    PageRequest.of(0, edu.bingol.backend.post.social.SocialFeedRepository.MAX_FOLLOWED_AUTHORS)));
            rows = c == null ? repo.followingFirst(viewer, authors, PageRequest.of(0, n + 1))
                    : repo.followingAfter(viewer, authors, at, cid, PageRequest.of(0, n + 1));
        } else {
            String dept = users.findById(viewer).map(u -> u.getDepartment()).filter(d -> d != null && !d.isBlank())
                    .orElse(null);
            if (dept == null) {
                return new FeedPage(List.of(), null, "NO_DEPARTMENT");
            }
            // A06#5: acik yazar listesi (bolum arkadaslari) -> yazar indeksi; alt sorgu yerine
            List<Long> authors = repo.departmentAuthors(viewer, dept,
                    PageRequest.of(0, edu.bingol.backend.post.social.SocialFeedRepository.MAX_DEPARTMENT_AUTHORS));
            if (authors.isEmpty()) {
                return page(viewer, List.of(), n, p -> PostCursor.latest(p.getCreatedAt(), p.getId()));
            }
            rows = c == null ? repo.followingFirst(viewer, authors, PageRequest.of(0, n + 1))
                    : repo.followingAfter(viewer, authors, at, cid, PageRequest.of(0, n + 1));
        }
        return page(viewer, rows, n, p -> PostCursor.latest(p.getCreatedAt(), p.getId()));
    }

    /** Bir kullanıcının gönderileri (engel ilişkisinde / pasif yazarda boş). */
    @Transactional(readOnly = true)
    public FeedPage byAuthor(Long viewer, Long authorId, String cursor, int size) {
        int n = clamp(size);
        // Gizli hesap: kabul edilmis takipci/sahibi degilse bos liste + locked=true (403 degil)
        if (gate != null && !gate.canSeeContent(viewer, authorId)) {
            return FeedPage.lockedPage();
        }
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<Post> rows = c == null
                ? posts.byAuthorFirst(authorId, viewer, PageRequest.of(0, n + 1))
                : posts.byAuthorAfter(authorId, viewer, c.at(), c.id(), PageRequest.of(0, n + 1));
        FeedPage out = page(viewer, rows, n, p -> PostCursor.latest(p.getCreatedAt(), p.getId()));
        return gate == null ? out : new FeedPage(out.items(), out.nextCursor(), out.hint(), Boolean.FALSE);
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
        // Gizli hesap sahibinin gonderisi takipci olmayana "bulunamadi" (var oldugunu da sizdirmaz)
        if (gate != null && !gate.canSeeContent(viewer, p.getAuthorId())) {
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

    /**
     * Metin temizligi: satir sonlari LF'ye indirgenir (CRLF, CR, NEL, U+2028/2029), kontrol karakterleri atilir
     * (sekme bosluk olur), uc bosluklar kirpilir. Bos sonuc null (metin serbest).
     */
    private static String normalize(String s) {
        if (s == null) {
            return null;
        }
        StringBuilder sb = new StringBuilder(s.length());
        int[] cps = s.codePoints().toArray();
        for (int i = 0; i < cps.length; i++) {
            int c = cps[i];
            if (c == '\r') {
                if (i + 1 < cps.length && cps[i + 1] == '\n') {
                    i++;
                }
                sb.append('\n');
            } else if (c == '\n' || c == 0x85 || c == 0x2028 || c == 0x2029 || c == 0x0B || c == 0x0C) {
                sb.append('\n');
            } else if (c == '\t') {
                sb.append(' ');
            } else if (Character.getType(c) == Character.CONTROL || c == 0x200B || c == 0xFEFF) {
                // kontrol / sifir genislikli karakterler atilir
            } else {
                sb.appendCodePoint(c);
            }
        }
        String t = sb.toString().replaceAll("^[\\s\\p{Z}]+|[\\s\\p{Z}]+$", "");
        return t.isEmpty() ? null : t;
    }

    /**
     * Gizli ust sinir (kullaniciya gosterilmez): en cok {@link PostDtos#POST_TEXT_MAX_CHARS} karakter (kod noktasi) ve
     * {@link PostDtos#POST_TEXT_MAX_LINES} satir; cok satirli metin serbest, bos metin serbest.
     */
    static void checkText(String text) {
        if (text == null) {
            return;
        }
        long lines = text.chars().filter(c -> c == '\n').count() + 1;
        if (text.codePointCount(0, text.length()) > PostDtos.POST_TEXT_MAX_CHARS || lines > PostDtos.POST_TEXT_MAX_LINES) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "POST_TEXT_TOO_LONG",
                    "Gönderi metni çok uzun.");
        }
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı.");
    }
}
