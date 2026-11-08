package edu.bingol.backend.post.reels;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostRank;
import edu.bingol.backend.post.PostRankProperties;
import edu.bingol.backend.post.PostRankRepository;
import edu.bingol.backend.post.PostViewAssembler;
import edu.bingol.backend.post.feed.FeedSeenService;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reels öneri akışı + kullanıcı izleme geçmişi + "Senin İçin" kişiselleştirme sırası. Kural tabanlı puan ({@link ReelsRanker},
 * ağırlıklar `app.post.reels.*`, ML yok).
 *
 * <p>Oturum = cursor'suz çağrıdan sonraki imleç zinciri (pull-to-refresh yeni oturum başlatır, yeni tohum alır). Aynı video
 * bir oturumda tekrar gelmez (Redis oturum kümesi). Normal modda bu kullanıcının {@code resurfaceAfterDays} içinde gördüğü
 * ve "ilgilenmiyorum" dediği videolar aday değildir (izlenmemişler öncelikli = yalnız izlenmemişler); aday kalmayınca
 * {@code exhausted=true} + boş/son sayfa döner (sonsuz döngü yok). {@code replay=true} geçmişi yok sayıp en az yakın zamanda
 * izlenenden başlayarak yeniden oynatma oturumu açar ("Tekrar izle"); "ilgilenmiyorum" yine hariçtir.
 * Servis sözleşmesi: yazma yöntemleri exception sızdırmaz (öneri geçmişi yardımcıdır).
 */
@Service
public class ReelsService {

    private static final Logger log = LoggerFactory.getLogger(ReelsService.class);

    private final PostWatchRepository watches;
    private final PostRankRepository ranks;
    private final PostViewAssembler assembler;
    private final ReelsProperties props;
    private final PostRankProperties rankProps;
    private final FeedSeenService seen;

    private final FamiliarityService familiarity;

    public ReelsService(PostWatchRepository watches, PostRankRepository ranks, PostViewAssembler assembler,
                        ReelsProperties props, PostRankProperties rankProps, FeedSeenService seen,
                        FamiliarityService familiarity) {
        this.familiarity = familiarity;
        this.watches = watches;
        this.ranks = ranks;
        this.assembler = assembler;
        this.props = props;
        this.rankProps = rankProps;
        this.seen = seen;
    }

    public ReelsProperties props() {
        return props;
    }

    // ------------------------------------------------------------------ akış

    @Transactional(readOnly = true)
    public FeedPage reels(Long viewer, String cursor, int size, boolean replay) {
        PostCursor.Reels c = PostCursor.decodeReels(cursor);
        boolean rep = c != null ? c.replay() : replay;
        String sid = c != null ? c.sid() : UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        long seed = c != null ? c.seed() : ThreadLocalRandom.current().nextLong();
        long lastAuthor = c != null ? c.lastAuthor() : 0L;
        int n = size <= 0 ? props.defaultPageSize() : Math.min(size, props.maxPageSize());
        Instant now = Instant.now();

        Set<Long> excl = new HashSet<>(watches.notInterestedIds(viewer));
        excl.addAll(seen.sessionIds(viewer, sid));
        if (!rep) {
            excl.addAll(watches.seenSince(viewer, now.minus(Duration.ofDays(Math.max(1, props.resurfaceAfterDays()))),
                    PageRequest.of(0, 2000)));
        }
        List<Post> cands = ranks.reelsFirst(viewer, excl.isEmpty() ? List.of(-1L) : excl,
                PageRequest.of(0, Math.max(props.poolSize(), n + 1)));
        if (cands.isEmpty()) {
            return new FeedPage(List.of(), null, null).withExhausted(true);
        }

        List<Post> sorted = score(viewer, cands, seed, now);
        sorted = PostRank.diversify(sorted, Post::getAuthorId, Math.max(1, props.maxAuthorRun()));
        sorted = avoidAuthorFirst(sorted, lastAuthor);
        boolean more = sorted.size() > n;
        List<Post> items = more ? new ArrayList<>(sorted.subList(0, n)) : sorted;
        String next = null;
        if (more) {
            next = PostCursor.reels(sid, seed, rep, items.get(items.size() - 1).getAuthorId());
        }
        seen.sessionAdd(viewer, sid, items.stream().map(Post::getId).toList());
        // sayfa son sayfaysa (daha aday yok) exhausted=true: istemci "Şimdilik tüm videoları gördün / Tekrar izle" gösterir
        return new FeedPage(assembler.assemble(viewer, items), next, null).withExhausted(next == null);
    }

    /** Puana göre azalan sıra (eşitlikte yeni id önce). */
    private List<Post> score(Long viewer, List<Post> cands, long seed, Instant now) {
        List<Long> ids = cands.stream().map(Post::getId).toList();
        List<Long> authors = cands.stream().map(Post::getAuthorId).distinct().toList();
        Set<Long> followed = new HashSet<>(watches.followedAmong(viewer, authors));
        Map<Long, Integer> likes = toIntMap(watches.likedAuthorCounts(viewer, authors));
        Map<Long, Integer> followers = toIntMap(ranks.followers(authors));
        Map<Long, PostWatch> hist = new HashMap<>();
        watches.ofUser(viewer, ids).forEach(w -> hist.put(w.getId().getPostId(), w));

        Map<Long, Double> scores = new HashMap<>();
        for (Post p : cands) {
            PostWatch w = hist.get(p.getId());
            boolean seenBefore = w != null && w.getImpressions() > 0;
            double hoursSince = seenBefore ? Duration.between(w.getLastSeenAt(), now).toSeconds() / 3600.0
                    : Double.MAX_VALUE;
            int disp = PostRank.displayScore(rankProps, p.getLikeCount(), followers.getOrDefault(p.getAuthorId(), 0),
                    p.getViewCount(), p.avgCompletion());
            double age = Duration.between(p.getCreatedAt(), now).toSeconds() / 3600.0;
            ReelsRanker.Features f = new ReelsRanker.Features(age, disp, followed.contains(p.getAuthorId()),
                    likes.getOrDefault(p.getAuthorId(), 0), seenBefore, hoursSince,
                    w == null ? 0 : w.getImpressions(), w == null ? 0 : w.getSkips(),
                    ReelsRanker.jitter(seed, p.getId()));
            scores.put(p.getId(), ReelsRanker.score(props, f));
        }
        List<Post> out = new ArrayList<>(cands);
        out.sort(Comparator.<Post>comparingDouble(p -> scores.get(p.getId())).reversed()
                .thenComparing(Comparator.comparing(Post::getId).reversed()));
        return out;
    }

    /** Önceki sayfanın son yazarı bu sayfanın ilki olmasın: ilk farklı yazarlıyı öne al. */
    private static List<Post> avoidAuthorFirst(List<Post> list, long lastAuthor) {
        if (lastAuthor <= 0 || list.size() < 2 || list.get(0).getAuthorId() != lastAuthor) {
            return list;
        }
        for (int i = 1; i < list.size(); i++) {
            if (list.get(i).getAuthorId() != lastAuthor) {
                List<Post> out = new ArrayList<>(list);
                out.add(0, out.remove(i));
                return out;
            }
        }
        return list;
    }

    /**
     * "Senin İçin": aday gönderileri (rank_score sırasında görülmemiş havuz) takip + yazar ilgisi + ortak popülerlik +
     * kontrollü rastgelelikle yeniden sıralar (aynı oturumda tohumla kararlı).
     */
    @Transactional(readOnly = true)
    public List<Post> orderForYou(Long viewer, List<Post> rows, long seed) {
        if (rows.size() < 2) {
            return rows;
        }
        try {
            List<Long> authors = rows.stream().map(Post::getAuthorId).distinct().toList();
            Set<Long> followed = new HashSet<>(watches.followedAmong(viewer, authors));
            Map<Long, Integer> likes = toIntMap(watches.likedAuthorCounts(viewer, authors));
            // Tanıdığın kişiler (karşılıklı takip, sohbet, ortak kulüp, aynı bölüm...): yalnız sırayı öne çeker
            Map<Long, Double> known = familiarity.bonuses(viewer, authors);
            Map<Long, Double> sc = new HashMap<>();
            for (Post p : rows) {
                sc.put(p.getId(), ReelsRanker.forYou(props, p.getRankScore(), followed.contains(p.getAuthorId()),
                        likes.getOrDefault(p.getAuthorId(), 0), ReelsRanker.jitter(seed, p.getId()))
                        + known.getOrDefault(p.getAuthorId(), 0.0));
            }
            List<Post> out = new ArrayList<>(rows);
            out.sort(Comparator.<Post>comparingDouble(p -> sc.get(p.getId())).reversed()
                    .thenComparing(Comparator.comparing(Post::getId).reversed()));
            return out;
        } catch (RuntimeException e) {
            log.warn("Senin Icin siralamasi basarisiz (rank sirasina dusuldu): {}", e.toString());
            return rows;
        }
    }

    // ------------------------------------------------------------------ izleme geçmişi

    /** Ekranda gösterilen video kimlikleri (POST /api/feed/seen): gösterim sayısı + son görülme. Video olmayanlar yok sayılır. */
    @Transactional
    public void recordImpressions(Long viewer, Collection<Long> ids) {
        try {
            if (ids == null || ids.isEmpty()) {
                return;
            }
            List<Long> videos = watches.videoIds(ids);
            if (videos.isEmpty()) {
                return;
            }
            Map<Long, PostWatch> existing = new HashMap<>();
            watches.ofUser(viewer, videos).forEach(w -> existing.put(w.getId().getPostId(), w));
            Instant now = Instant.now();
            List<PostWatch> out = new ArrayList<>();
            for (Long id : videos) {
                PostWatch w = existing.computeIfAbsent(id, k -> new PostWatch(viewer, k));
                w.setImpressions(w.getImpressions() + 1);
                w.setLastSeenAt(now);
                out.add(w);
            }
            watches.saveAll(out);
        } catch (RuntimeException e) {
            log.debug("izleme gecmisi (gosterim) yazilamadi: {}", e.toString());
        }
    }

    /** İzleme olayı (POST /api/posts/{id}/view): süre, tamamlanma, hızlı geçme. Yalnız başkasının görünür videosu. */
    @Transactional
    public void recordWatch(Long viewer, Long postId, long watchedMs, long clientDurationMs) {
        try {
            List<Post> vids = ranks.visibleVideosByIds(viewer, List.of(postId));
            if (vids.isEmpty() || vids.get(0).getAuthorId().equals(viewer)) {
                return;
            }
            long dur = clientDurationMs;
            long cap = dur > 0 ? dur * 10 : 36_000_000L; // döngüde aşırı toplam süreyi sınırla
            long ms = Math.max(0, Math.min(watchedMs, cap));
            PostWatch w = watches.findById(new PostWatchId(viewer, postId)).orElseGet(() -> {
                PostWatch nw = new PostWatch(viewer, postId);
                nw.setImpressions(1);
                return nw;
            });
            int pct = dur > 0 ? (int) Math.min(100, ms * 100 / dur) : 0;
            w.setWatchMs(w.getWatchMs() + ms);
            w.setCompletionPct((short) Math.max(w.getCompletionPct(), pct));
            boolean quick = ms < props.quickSkipMs() || (dur >= 5000 && pct < props.quickSkipPct());
            if (quick) {
                w.setSkips(w.getSkips() + 1);
            }
            w.setLastSeenAt(Instant.now());
            watches.save(w);
        } catch (RuntimeException e) {
            log.debug("izleme gecmisi (izleme) yazilamadi: {}", e.toString());
        }
    }

    /** "İlgilenmiyorum": gönderi Reels ve "Senin İçin" önerilerinden kalkar. Geri alma: value=false. */
    @Transactional
    public void setNotInterested(Long viewer, Long postId, boolean value) {
        PostWatch w = watches.findById(new PostWatchId(viewer, postId)).orElseGet(() -> new PostWatch(viewer, postId));
        w.setNotInterested(value);
        w.setLastSeenAt(Instant.now());
        watches.save(w);
    }

    /** Hesap silme (KVKK). */
    @Transactional
    public void purge(Long userId) {
        watches.deleteByUser(userId);
    }

    private static Map<Long, Integer> toIntMap(List<Object[]> rows) {
        Map<Long, Integer> m = new HashMap<>();
        for (Object[] r : rows) {
            m.put(((Number) r[0]).longValue(), ((Number) r[1]).intValue());
        }
        return m;
    }
}
