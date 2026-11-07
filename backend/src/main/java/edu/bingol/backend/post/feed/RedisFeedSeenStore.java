package edu.bingol.backend.post.feed;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.DefaultTypedTuple;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ZSetOperations.TypedTuple;
import org.springframework.stereotype.Component;

/** Redis `feedseen:uid` sorted set (skor = damga, TTL 48 sa) ve `pview:pid:uid` tekil izlenme anahtarı. */
@Component
@ConditionalOnProperty(name = "app.feed.seen-store", havingValue = "redis", matchIfMissing = true)
public class RedisFeedSeenStore implements FeedSeenStore {

    private final StringRedisTemplate redis;

    public RedisFeedSeenStore(StringRedisTemplate redis) {
        this.redis = redis;
    }

    static String key(long userId) {
        return "feedseen:" + userId;
    }

    @Override
    public void add(long userId, Collection<Long> postIds, long baseStamp, int max, Duration ttl) {
        if (postIds.isEmpty()) {
            return;
        }
        String k = key(userId);
        Set<TypedTuple<String>> tuples = new LinkedHashSet<>();
        long i = 0;
        for (Long id : postIds) {
            tuples.add(new DefaultTypedTuple<>(String.valueOf(id), (double) (baseStamp + i++)));
        }
        redis.opsForZSet().add(k, tuples);
        // en eskileri at: yalnız son `max` öğe kalır
        redis.opsForZSet().removeRange(k, 0, -(long) max - 1);
        redis.expire(k, ttl);
    }

    @Override
    public List<Entry> all(long userId) {
        return toEntries(redis.opsForZSet().rangeWithScores(key(userId), 0, -1));
    }

    @Override
    public List<Entry> range(long userId, long afterExclusive, long beforeExclusive, int limit) {
        // damgalar tam sayı ve 2^53'ten küçük: aralık sınırları +-1 ile dışlanır
        Set<TypedTuple<String>> r = redis.opsForZSet().rangeByScoreWithScores(key(userId), afterExclusive + 1.0,
                beforeExclusive - 1.0, 0, limit);
        return toEntries(r);
    }

    @Override
    public void sessionAdd(String key, Collection<Long> postIds, Duration ttl) {
        if (postIds.isEmpty()) {
            return;
        }
        redis.opsForSet().add(key, postIds.stream().map(String::valueOf).toArray(String[]::new));
        redis.expire(key, ttl);
    }

    @Override
    public Set<Long> sessionIds(String key) {
        Set<String> raw = redis.opsForSet().members(key);
        Set<Long> out = new LinkedHashSet<>();
        if (raw != null) {
            for (String s : raw) {
                try {
                    out.add(Long.parseLong(s));
                } catch (NumberFormatException ignored) {
                    // bozuk uye: atla
                }
            }
        }
        return out;
    }

    @Override
    public void delete(long userId) {
        redis.delete(key(userId));
    }

    @Override
    public boolean claim(String key, Duration ttl) {
        return Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(key, "1", ttl));
    }

    private static List<Entry> toEntries(Set<TypedTuple<String>> set) {
        List<Entry> out = new ArrayList<>();
        if (set == null) {
            return out;
        }
        for (TypedTuple<String> t : set) {
            if (t.getValue() == null || t.getScore() == null) {
                continue;
            }
            try {
                out.add(new Entry(Long.parseLong(t.getValue()), t.getScore().longValue()));
            } catch (NumberFormatException ignored) {
                // bozuk üye: atla
            }
        }
        return out;
    }
}
