package edu.bingol.backend.post.popularity;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Kullanıcı "Popülerlik puanı" (0..100): takipçi sayısı + aldığı toplam beğeni + gönderi sayısı, log ölçekli ve
 * tavanlı (bkz. {@link PopularityProperties}). Yalnız gerçek sayılardan türetilir; rozet/ödül yoktur.
 * Saatlik toplu iş {@code user_popularity} tablosunu günceller; okuma satırı kullanır, satırı olmayan (yeni) kullanıcı
 * için anında hesaplar. Servis sözleşmesi: zamanlayıcı exception sızdırmaz.
 */
@Service
public class UserPopularityService {

    private static final Logger log = LoggerFactory.getLogger(UserPopularityService.class);

    /** Gösterilen değerler: puan 0..100 ve bileşenler. */
    public record Snapshot(int score, int followerCount, long likesReceived, int postCount) {
        public static final Snapshot ZERO = new Snapshot(0, 0, 0, 0);
    }

    private final UserPopularityRepository repo;
    private final PopularityProperties props;
    private final SchedulerLock lock;
    private final TransactionTemplate tx;

    public UserPopularityService(UserPopularityRepository repo, PopularityProperties props, SchedulerLock lock,
                                 TransactionTemplate tx) {
        this.repo = repo;
        this.props = props;
        this.lock = lock;
        this.tx = tx;
    }

    // ------------------------------------------------------------------ saf formül

    /** 0..100 puan (saf fonksiyon; test edilebilir). */
    public static int score(PopularityProperties p, long followers, long likes, long posts) {
        double wf = Math.max(p.followerWeight(), 0);
        double wl = Math.max(p.likeWeight(), 0);
        double wp = Math.max(p.postWeight(), 0);
        double sum = wf + wl + wp;
        if (sum <= 0) {
            return 0;
        }
        double v = wf * comp(followers, p.followerCap()) + wl * comp(likes, p.likeCap())
                + wp * comp(posts, p.postCap());
        return (int) Math.max(0, Math.min(100, Math.round(100.0 * v / sum)));
    }

    private static double comp(long x, int cap) {
        if (x <= 0 || cap <= 0) {
            return 0;
        }
        return Math.min(1.0, Math.log1p(x) / Math.log1p(cap));
    }

    // ------------------------------------------------------------------ okuma

    /** Tek kullanıcı: satır varsa onu (en çok 1 saat eski), yoksa anında hesaplar (yazmaz). */
    @Transactional(readOnly = true)
    public Snapshot of(Long userId) {
        if (userId == null) {
            return Snapshot.ZERO;
        }
        return forUsers(List.of(userId)).getOrDefault(userId, Snapshot.ZERO);
    }

    /** Toplu: satırı olanlar tablodan, olmayanlar tek turda anında hesaplanır (yazılmaz). */
    @Transactional(readOnly = true)
    public Map<Long, Snapshot> forUsers(Collection<Long> userIds) {
        Map<Long, Snapshot> out = new HashMap<>();
        if (userIds == null || userIds.isEmpty()) {
            return out;
        }
        List<Long> ids = userIds.stream().distinct().toList();
        for (UserPopularity r : repo.findAllById(ids)) {
            out.put(r.getUserId(), new Snapshot(r.getScore(), r.getFollowerCount(), r.getLikesReceived(),
                    r.getPostCount()));
        }
        List<Long> missing = ids.stream().filter(id -> !out.containsKey(id)).toList();
        if (!missing.isEmpty()) {
            out.putAll(compute(missing));
        }
        return out;
    }

    /** Anında hesap (3 indeksli toplu sorgu); tablo yazmaz. */
    @Transactional(readOnly = true)
    public Map<Long, Snapshot> compute(Collection<Long> userIds) {
        Map<Long, Snapshot> out = new HashMap<>();
        if (userIds == null || userIds.isEmpty()) {
            return out;
        }
        Map<Long, Integer> followers = new HashMap<>();
        for (Object[] r : repo.followers(userIds)) {
            followers.put(((Number) r[0]).longValue(), ((Number) r[1]).intValue());
        }
        Map<Long, long[]> agg = new HashMap<>();
        for (Object[] r : repo.postAggregates(userIds)) {
            agg.put(((Number) r[0]).longValue(), new long[] {((Number) r[1]).longValue(), ((Number) r[2]).longValue()});
        }
        for (Long id : userIds) {
            int f = followers.getOrDefault(id, 0);
            long[] a = agg.getOrDefault(id, new long[] {0, 0});
            int posts = (int) Math.min(a[0], Integer.MAX_VALUE);
            out.put(id, new Snapshot(score(props, f, a[1], posts), f, a[1], posts));
        }
        return out;
    }

    // ------------------------------------------------------------------ toplu iş

    @Scheduled(fixedDelayString = "${app.post.popularity.recompute-ms:3600000}",
            initialDelayString = "${app.post.popularity.initial-delay-ms:120000}")
    public void scheduled() {
        try {
            long ttl = Math.max(props.recomputeMs(), 60_000L);
            lock.tryRun("user-popularity", Duration.ofMillis(ttl), this::recomputeAll);
        } catch (RuntimeException e) {
            log.warn("Populerlik puani isi basarisiz: {}", e.toString());
        }
    }

    /** Kilitsiz çekirdek (test / elle tetikleme): tüm aktif kullanıcılar, değişen satırlar yazılır. */
    public void recomputeAll() {
        long after = 0;
        int batch = Math.max(50, props.batchSize());
        while (true) {
            final long cursor = after;
            Long last = tx.execute(s -> {
                List<Long> ids = repo.activeIdsAfter(cursor, PageRequest.of(0, batch));
                if (ids.isEmpty()) {
                    return null;
                }
                Map<Long, Snapshot> fresh = compute(ids);
                Map<Long, UserPopularity> rows = new HashMap<>();
                repo.findAllById(ids).forEach(r -> rows.put(r.getUserId(), r));
                List<UserPopularity> changed = new ArrayList<>();
                Instant now = Instant.now();
                for (Long id : ids) {
                    Snapshot sn = fresh.getOrDefault(id, Snapshot.ZERO);
                    UserPopularity r = rows.get(id);
                    if (r == null) {
                        r = new UserPopularity();
                        r.setUserId(id);
                    } else if (r.getScore() == sn.score() && r.getFollowerCount() == sn.followerCount()
                            && r.getLikesReceived() == sn.likesReceived() && r.getPostCount() == sn.postCount()) {
                        continue; // değişmedi: yazma yok
                    }
                    r.setScore((short) sn.score());
                    r.setFollowerCount(sn.followerCount());
                    r.setLikesReceived(sn.likesReceived());
                    r.setPostCount(sn.postCount());
                    r.setComputedAt(now);
                    changed.add(r);
                }
                if (!changed.isEmpty()) {
                    repo.saveAll(changed);
                }
                return ids.size() < batch ? null : ids.get(ids.size() - 1);
            });
            if (last == null) {
                return;
            }
            after = last;
        }
    }

    /** Hesap silme (KVKK): kullanıcının puan satırı silinir. */
    @Transactional
    public void purge(Long userId) {
        repo.deleteByUser(userId);
    }
}
