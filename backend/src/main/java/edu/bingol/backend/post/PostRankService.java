package edu.bingol.backend.post;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Keşfet puanı hibrit güncelleme: (1) yeni gönderi oluşurken tek seferlik soğuk başlangıç puanı (anında görünür),
 * (2) her recomputeMs (5 dk) SchedulerLock ile sarılı toplu yeniden hesap (sönüm, beğeni/takip değişimi, şikâyet).
 * Beğeni başına artımlı yazma yapılmaz: yazma yolunu (hot path) yavaşlatmaz; 5 dk gecikme kabul edilir.
 * Sözleşme: exception sızdırmaz.
 */
@Service
public class PostRankService {

    private static final Logger log = LoggerFactory.getLogger(PostRankService.class);
    private static final int BATCH = 500;

    private final PostRepository posts;
    private final PostRankRepository ranks;
    private final PostRankProperties props;
    private final SchedulerLock lock;
    private final TransactionTemplate tx;

    /** Hesap sürümü: son yeniden hesap anı (epoch sn); imlece yazılır, değişmişse hint=RANK_REFRESHED döner. Örneğe özeldir. */
    private final AtomicLong version = new AtomicLong(Instant.now().getEpochSecond());

    public PostRankService(PostRepository posts, PostRankRepository ranks, PostRankProperties props,
                           SchedulerLock lock, TransactionTemplate tx) {
        this.posts = posts;
        this.ranks = ranks;
        this.props = props;
        this.lock = lock;
        this.tx = tx;
    }

    public PostRankProperties props() {
        return props;
    }

    public long version() {
        return version.get();
    }

    /** Yeni gönderi puanı: beğeni/yorum yok, yaş 0 -> takipçi + soğuk başlangıç bonusu. */
    public double initialScore(Post p) {
        try {
            List<Integer> f = ranks.followersOf(p.getAuthorId());
            return PostRank.compute(props, 0, 0, f.isEmpty() ? 0 : f.get(0), 0, 0, 0);
        } catch (RuntimeException e) {
            log.warn("Ilk gonderi puani hesaplanamadi: {}", e.toString());
            return props.coldStartBonus();
        }
    }

    @Scheduled(fixedDelayString = "${app.post.rank.recompute-ms:300000}",
            initialDelayString = "${app.post.rank.initial-delay-ms:30000}")
    public void scheduled() {
        try {
            long ttl = Math.max(props.recomputeMs(), 60_000L);
            lock.tryRun("post-rank", Duration.ofMillis(ttl), this::recompute);
        } catch (RuntimeException e) {
            log.warn("Kesfet puan isi basarisiz: {}", e.toString());
        }
    }

    /** Kilitsiz çekirdek (test / elle tetikleme). */
    public void recompute() {
        Instant now = Instant.now();
        Instant since = now.minus(Duration.ofDays(props.windowDays()));
        tx.executeWithoutResult(s -> ranks.zeroOld(since));
        long after = 0;
        while (true) {
            final long cursor = after;
            Long last = tx.execute(s -> {
                List<Post> batch = posts.scoreBatch(since, cursor, PageRequest.of(0, BATCH));
                if (batch.isEmpty()) {
                    return null;
                }
                List<Long> ids = batch.stream().map(Post::getId).toList();
                List<Long> authors = batch.stream().map(Post::getAuthorId).distinct().toList();
                Map<Long, Integer> followers = toMap(ranks.followers(authors));
                Map<Long, Integer> recent = toMap(ranks.recentLikes(ids, now.minus(Duration.ofHours(24))));
                Map<Long, Integer> reports = toMap(ranks.openReports(ids));
                List<Post> changed = new java.util.ArrayList<>();
                for (Post p : batch) {
                    double ageH = Duration.between(p.getCreatedAt(), now).toSeconds() / 3600.0;
                    double score = PostRank.compute(props, p.getLikeCount(), 0,
                            followers.getOrDefault(p.getAuthorId(), 0), recent.getOrDefault(p.getId(), 0),
                            reports.getOrDefault(p.getId(), 0), ageH);
                    // T-075 (A2-14): sonum nedeniyle her turda binlerce satir yeniden yazilmasin; anlamli degisim esikli
                    if (shouldWrite(p.getRankScore(), score)) {
                        p.setRankScore(score);
                        changed.add(p);
                    }
                }
                if (!changed.isEmpty()) {
                    posts.saveAll(changed);
                }
                return batch.size() < BATCH ? null : batch.get(batch.size() - 1).getId();
            });
            if (last == null) {
                break;
            }
            after = last;
        }
        version.set(now.getEpochSecond());
    }

    /** Mutlak 0,001 ya da eski puanin %1'i kadar degisim yazilir (siralama icin onemsiz sapmalar atlanir). */
    static boolean shouldWrite(double old, double next) {
        return Math.abs(next - old) > Math.max(0.001, 0.01 * Math.abs(old));
    }

    private static Map<Long, Integer> toMap(List<Object[]> rows) {
        Map<Long, Integer> m = new HashMap<>();
        for (Object[] r : rows) {
            m.put(((Number) r[0]).longValue(), ((Number) r[1]).intValue());
        }
        return m;
    }
}
