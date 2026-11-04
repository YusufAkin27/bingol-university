package edu.bingol.backend.post.feed;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** Bellek içi depo (yalnız test/geliştirme: `app.feed.seen-store=memory`); TTL uygulanmaz. */
@Component
@ConditionalOnProperty(name = "app.feed.seen-store", havingValue = "memory")
public class InMemoryFeedSeenStore implements FeedSeenStore {

    private final Map<Long, Map<Long, Long>> seen = new HashMap<>();
    private final Map<String, Boolean> claims = new HashMap<>();

    @Override
    public synchronized void add(long userId, Collection<Long> postIds, long baseStamp, int max, Duration ttl) {
        Map<Long, Long> m = seen.computeIfAbsent(userId, k -> new HashMap<>());
        long i = 0;
        for (Long id : postIds) {
            m.put(id, baseStamp + i++);
        }
        if (m.size() > max) {
            List<Entry> sorted = sorted(m);
            for (int k = 0; k < sorted.size() - max; k++) {
                m.remove(sorted.get(k).postId());
            }
        }
    }

    @Override
    public synchronized List<Entry> all(long userId) {
        return sorted(seen.getOrDefault(userId, Map.of()));
    }

    @Override
    public synchronized List<Entry> range(long userId, long afterExclusive, long beforeExclusive, int limit) {
        List<Entry> out = new ArrayList<>();
        for (Entry e : sorted(seen.getOrDefault(userId, Map.of()))) {
            if (e.stamp() > afterExclusive && e.stamp() < beforeExclusive) {
                out.add(e);
                if (out.size() >= limit) {
                    break;
                }
            }
        }
        return out;
    }

    private final Map<String, java.util.Set<Long>> sessions = new HashMap<>();

    @Override
    public synchronized void sessionAdd(String key, Collection<Long> postIds, Duration ttl) {
        sessions.computeIfAbsent(key, k -> new java.util.LinkedHashSet<>()).addAll(postIds);
    }

    @Override
    public synchronized java.util.Set<Long> sessionIds(String key) {
        return new java.util.LinkedHashSet<>(sessions.getOrDefault(key, java.util.Set.of()));
    }

    @Override
    public synchronized void delete(long userId) {
        seen.remove(userId);
    }

    @Override
    public synchronized boolean claim(String key, Duration ttl) {
        return claims.putIfAbsent(key, Boolean.TRUE) == null;
    }

    private static List<Entry> sorted(Map<Long, Long> m) {
        List<Entry> out = new ArrayList<>(m.size());
        m.forEach((id, st) -> out.add(new Entry(id, st)));
        out.sort(Comparator.comparingLong(Entry::stamp).thenComparingLong(Entry::postId));
        return out;
    }
}
