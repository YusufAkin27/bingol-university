package edu.bingol.backend.post.feed;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * "Görülmüş" gönderi kümesi (Keşfet/Reels tekrar göstermeme). Kısa ömürlü teknik veridir (48 sa, en çok 2000 öğe);
 * kişisel veri dışa aktarımına girmez, hesap silinince {@link #forget} ile silinir. Servis sözleşmesi: depo hatası
 * çağırana sızmaz (okumada boş küme, yazmada sessiz atlama): görülmüş kümesi yardımcıdır, akışı düşürmez.
 */
@Service
public class FeedSeenService {

    private static final Logger log = LoggerFactory.getLogger(FeedSeenService.class);

    private final FeedSeenStore store;

    @Value("${app.feed.seen-max:2000}")
    private int max = 2000;
    @Value("${app.feed.seen-ttl-hours:48}")
    private int ttlHours = 48;
    @Value("${app.feed.view-dedupe-hours:6}")
    private int viewDedupeHours = 6;

    public FeedSeenService(FeedSeenStore store) {
        this.store = store;
    }

    /** Görülmüş kimlikler + damga (eskiden yeniye). */
    public List<FeedSeenStore.Entry> entries(Long userId) {
        try {
            return store.all(userId);
        } catch (RuntimeException e) {
            log.debug("feedseen okunamadi: {}", e.toString());
            return List.of();
        }
    }

    public Set<Long> ids(Long userId) {
        Set<Long> out = new LinkedHashSet<>();
        entries(userId).forEach(e -> out.add(e.postId()));
        return out;
    }

    /** Süreç içi tekdüze damga sayacı: aynı milisaniyedeki iki çağrı aynı damgayı üretmesin (imleç tekilliği). */
    private static final AtomicLong LAST_BASE = new AtomicLong();

    /** Kimlikleri görülmüş sayar; damga = şimdi (aynı çağrıda sıralı). Döner: bu çağrının taban damgası. */
    public long mark(Long userId, Collection<Long> postIds) {
        long now = stamp(System.currentTimeMillis());
        if (userId == null || postIds == null || postIds.isEmpty()) {
            return now;
        }
        List<Long> ids = new ArrayList<>(new LinkedHashSet<>(postIds));
        long base;
        synchronized (LAST_BASE) { // bu çağrının damga aralığını ayır (base .. base+ids.size()-1)
            base = Math.max(now, LAST_BASE.get() + 1);
            LAST_BASE.set(base + ids.size());
        }
        try {
            store.add(userId, ids, base, max, Duration.ofHours(ttlHours));
        } catch (RuntimeException e) {
            log.debug("feedseen yazilamadi: {}", e.toString());
        }
        return base;
    }

    /** (after, before) damga aralığındaki eski görülmüşler (eskiden yeniye). */
    public List<FeedSeenStore.Entry> range(Long userId, long afterExclusive, long beforeExclusive, int limit) {
        try {
            return store.range(userId, afterExclusive, beforeExclusive, limit);
        } catch (RuntimeException e) {
            log.debug("feedseen aralik okunamadi: {}", e.toString());
            return List.of();
        }
    }

    public void forget(Long userId) {
        try {
            store.delete(userId);
        } catch (RuntimeException e) {
            log.debug("feedseen silinemedi: {}", e.toString());
        }
    }

    @Value("${app.post.reels.session-ttl-hours:6}")
    private int sessionTtlHours = 6;

    /** Reels oturumunda (pull-to-refresh'ten pull-to-refresh'e) gösterilenler: aynı video oturumda tekrar gelmez. */
    public void sessionAdd(Long userId, String sid, Collection<Long> postIds) {
        try {
            store.sessionAdd("reelsess:" + userId + ":" + sid, new ArrayList<>(new LinkedHashSet<>(postIds)),
                    Duration.ofHours(sessionTtlHours));
        } catch (RuntimeException e) {
            log.debug("reels oturumu yazilamadi: {}", e.toString());
        }
    }

    public Set<Long> sessionIds(Long userId, String sid) {
        try {
            return store.sessionIds("reelsess:" + userId + ":" + sid);
        } catch (RuntimeException e) {
            log.debug("reels oturumu okunamadi: {}", e.toString());
            return Set.of();
        }
    }

    /** Aynı kullanıcı aynı gönderiyi `viewDedupeHours` içinde tek izlenme sayar; depo hatasında sayılmaz (şişirme yok). */
    public boolean claimView(Long userId, Long postId) {
        try {
            return store.claim("pview:" + postId + ":" + userId, Duration.ofHours(viewDedupeHours));
        } catch (RuntimeException e) {
            log.debug("izlenme tekillestirme basarisiz: {}", e.toString());
            return false;
        }
    }

    /** Milisaniye -> damga (x1000; aynı çağrıdaki öğeler +0, +1, ... ile sıralanır). */
    public static long stamp(long millis) {
        return millis * 1000L;
    }
}
