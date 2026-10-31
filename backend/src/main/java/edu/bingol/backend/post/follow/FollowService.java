package edu.bingol.backend.post.follow;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.notify.PostNotifier;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Takip sistemi. Kurallar: kendini takip edemez (400 FOLLOW_SELF); pasif/dogrulanmamis ya da engel iliskisindeki
 * kullanici 404 USER_NOT_FOUND; idempotent. Sayaclar user_follow_stats tablosunda atomik SQL ile tutulur.
 */
@Service
public class FollowService {

    public record FollowResult(boolean following, long followerCount) {}

    public record Stats(long followerCount, long followingCount, boolean followedByMe, boolean followsMe) {
        public Stats(long followerCount, long followingCount, boolean followedByMe) {
            this(followerCount, followingCount, followedByMe, false);
        }
    }

    /** classYear: profil gizlilik ayarina gore (bakana kapaliysa null). */
    public record UserItem(Long id, String displayName, String avatarUrl, String department, boolean followedByMe,
                           boolean followsMe, Short classYear) {
        public UserItem(Long id, String displayName, String avatarUrl, String department, boolean followedByMe,
                        boolean followsMe) {
            this(id, displayName, avatarUrl, department, followedByMe, followsMe, null);
        }

        public UserItem(Long id, String displayName, String avatarUrl, String department, boolean followedByMe) {
            this(id, displayName, avatarUrl, department, followedByMe, false, null);
        }
    }

    public record UserPage(List<UserItem> items, String nextCursor) {}

    public record Suggestion(Long id, String displayName, String avatarUrl, String department, String reason,
                             Short classYear) {
        public Suggestion(Long id, String displayName, String avatarUrl, String department, String reason) {
            this(id, displayName, avatarUrl, department, reason, null);
        }
    }

    private final JdbcTemplate jdbc;
    private final UserFollowRepository follows;
    private final UserRepository users;
    private final BlockService blocks;
    private final PublicProfileMapper profiles;
    private final ObjectProvider<PostNotifier> notifier;

    public FollowService(JdbcTemplate jdbc, UserFollowRepository follows, UserRepository users, BlockService blocks,
                         PublicProfileMapper profiles, ObjectProvider<PostNotifier> notifier) {
        this.jdbc = jdbc;
        this.follows = follows;
        this.users = users;
        this.blocks = blocks;
        this.profiles = profiles;
        this.notifier = notifier;
    }

    // ---------------------------------------------------------------- takip et / birak

    @Transactional
    public FollowResult follow(Long me, Long target) {
        if (me.equals(target)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FOLLOW_SELF", "Kendinizi takip edemezsiniz.");
        }
        User t = users.findById(target).orElseThrow(FollowService::notFound);
        if (!t.isActive() || !t.isEmailVerified() || blocks.isBlocked(me, target)) {
            throw notFound();
        }
        int n = jdbc.update("INSERT INTO user_follow (follower_id, followee_id, created_at) SELECT ?, ?, CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM user_follow WHERE follower_id = ? AND followee_id = ?)",
                me, target, me, target);
        if (n > 0) {
            ensureStats(me);
            ensureStats(target);
            jdbc.update("UPDATE user_follow_stats SET following_count = following_count + 1 WHERE user_id = ?", me);
            jdbc.update("UPDATE user_follow_stats SET follower_count = follower_count + 1 WHERE user_id = ?", target);
            afterCommit(() -> {
                PostNotifier pn = notifier.getIfAvailable();
                if (pn != null) {
                    pn.onFollow(me, target);
                }
            });
        }
        return new FollowResult(true, followerCount(target));
    }

    @Transactional
    public FollowResult unfollow(Long me, Long target) {
        int n = jdbc.update("DELETE FROM user_follow WHERE follower_id = ? AND followee_id = ?", me, target);
        if (n > 0) {
            jdbc.update("UPDATE user_follow_stats SET following_count = CASE WHEN following_count > 0 "
                    + "THEN following_count - 1 ELSE 0 END WHERE user_id = ?", me);
            jdbc.update("UPDATE user_follow_stats SET follower_count = CASE WHEN follower_count > 0 "
                    + "THEN follower_count - 1 ELSE 0 END WHERE user_id = ?", target);
        }
        return new FollowResult(false, followerCount(target));
    }

    private void ensureStats(Long uid) {
        try {
            jdbc.update("INSERT INTO user_follow_stats (user_id, follower_count, following_count) SELECT ?, 0, 0 "
                    + "WHERE NOT EXISTS (SELECT 1 FROM user_follow_stats WHERE user_id = ?)", uid, uid);
        } catch (DuplicateKeyException ignored) {
            // es zamanli ilk takip: satir baska islemce acildi
        }
    }

    // ---------------------------------------------------------------- sayaclar

    @Transactional(readOnly = true)
    public long followerCount(Long uid) {
        List<Integer> r = jdbc.queryForList("SELECT follower_count FROM user_follow_stats WHERE user_id = ?",
                Integer.class, uid);
        return r.isEmpty() ? 0 : r.get(0);
    }

    /** Profil gorunumu icin: sayaclar + bakanin takip durumu. */
    @Transactional(readOnly = true)
    public Stats stats(Long viewer, Long target) {
        List<long[]> r = jdbc.query("SELECT follower_count, following_count FROM user_follow_stats WHERE user_id = ?",
                (rs, i) -> new long[] {rs.getLong(1), rs.getLong(2)}, target);
        long[] c = r.isEmpty() ? new long[] {0, 0} : r.get(0);
        boolean mine = viewer != null && !viewer.equals(target) && follows.existsById(new edu.bingol.backend.post.social.PairId(viewer, target));
        boolean theirs = viewer != null && !viewer.equals(target)
                && follows.existsById(new edu.bingol.backend.post.social.PairId(target, viewer));
        return new Stats(c[0], c[1], mine, theirs);
    }

    // ---------------------------------------------------------------- listeler

    @Transactional(readOnly = true)
    public UserPage followers(Long viewer, Long target, String cursor, int size) {
        return page(viewer, target, cursor, size, true);
    }

    @Transactional(readOnly = true)
    public UserPage following(Long viewer, Long target, String cursor, int size) {
        return page(viewer, target, cursor, size, false);
    }

    private UserPage page(Long viewer, Long target, String cursor, int size, boolean followers) {
        int n = size <= 0 ? 20 : Math.min(size, 30);
        User t = users.findById(target).orElse(null);
        if (t == null || !t.isActive() || (!viewer.equals(target) && blocks.isBlocked(viewer, target))) {
            return new UserPage(List.of(), null);
        }
        PostCursor c = PostCursor.decode(cursor, 'L');
        PageRequest pr = PageRequest.of(0, n + 1);
        List<UserFollow> rows;
        if (followers) {
            rows = c == null ? follows.followersFirst(target, viewer, pr)
                    : follows.followersAfter(target, viewer, c.at(), c.id(), pr);
        } else {
            rows = c == null ? follows.followingFirst(target, viewer, pr)
                    : follows.followingAfter(target, viewer, c.at(), c.id(), pr);
        }
        boolean more = rows.size() > n;
        List<UserFollow> items = more ? rows.subList(0, n) : rows;
        Function<UserFollow, Long> other = f -> followers ? f.getId().getA() : f.getId().getB();
        List<Long> ids = items.stream().map(other).toList();
        String next = more ? PostCursor.latest(items.get(items.size() - 1).getCreatedAt(),
                other.apply(items.get(items.size() - 1))) : null;
        return new UserPage(userItems(viewer, ids), next);
    }

    private List<UserItem> userItems(Long viewer, List<Long> ids) {
        if (ids.isEmpty()) {
            return List.of();
        }
        Map<Long, PublicProfile> byId = new HashMap<>();
        profiles.mapAll(viewer, users.findAllById(ids)).forEach(p -> byId.put(p.id(), p));
        Set<Long> mine = new HashSet<>(follows.followedAmong(viewer, ids));
        Set<Long> theirs = new HashSet<>(follows.followingMeAmong(viewer, ids));
        List<UserItem> out = new ArrayList<>();
        for (Long id : ids) {
            PublicProfile p = byId.get(id);
            if (p != null) {
                boolean self = id.equals(viewer);
                out.add(new UserItem(p.id(), p.displayName(), p.avatarUrl(), p.department(),
                        !self && mine.contains(id), !self && theirs.contains(id), p.classYear()));
            }
        }
        return out;
    }

    // ---------------------------------------------------------------- oneriler

    /** Onerilen aday ust siniri (kulup arkadasi ve bolum havuzu ayri ayri); sorgu maliyetini kullanici sayisindan ayirir. */
    static final int SUGGESTION_POOL = 300;
    /** Onbellege alinan sirali aday sayisi (en fazla 20 istenir; takip/engel sonradan suzuldugu icin pay birakilir). */
    private static final int SUGGESTION_CACHE_ROWS = 40;
    private static final long SUGGESTION_TTL_MS = 15 * 60_000L;
    private static final int SUGGESTION_CACHE_MAX = 5_000;

    private record CachedRows(long at, List<Object[]> rows) {}

    /** Kullanici basina sirali aday listesi (id, neden); LRU + TTL. Takip/engel okuma aninda suzulur, bu yuzden bayatlamaz. */
    private final Map<Long, CachedRows> suggestionCache = new java.util.LinkedHashMap<>(256, 0.75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<Long, CachedRows> eldest) {
            return size() > SUGGESTION_CACHE_MAX;
        }
    };

    void clearSuggestionCache() {
        synchronized (suggestionCache) {
            suggestionCache.clear();
        }
    }

    /** Ortak kulup, ayni bolum+sinif, ayni bolum; takip edilenler ve engel iliskileri haric. */
    @Transactional(readOnly = true)
    public List<Suggestion> suggestions(Long me, int size) {
        int n = size <= 0 ? 10 : Math.min(size, 20);
        List<Object[]> rows = suggestionRows(me);
        if (rows.isEmpty()) {
            return List.of();
        }
        // Onbellek bayatlamasin: sonradan takip edilen / engellenen adaylari okuma aninda ele (iki kucuk sorgu)
        List<Long> cachedIds = rows.stream().map(r -> (Long) r[0]).toList();
        Set<Long> skip = new HashSet<>(follows.followedAmong(me, cachedIds));
        String in = String.join(",", java.util.Collections.nCopies(cachedIds.size(), "?"));
        Object[] args = new Object[cachedIds.size() * 2 + 2];
        args[0] = me;
        for (int i = 0; i < cachedIds.size(); i++) {
            args[1 + i] = cachedIds.get(i);
        }
        args[cachedIds.size() + 1] = me;
        for (int i = 0; i < cachedIds.size(); i++) {
            args[cachedIds.size() + 2 + i] = cachedIds.get(i);
        }
        skip.addAll(jdbc.queryForList("SELECT blocked_id FROM user_block WHERE blocker_id = ? AND blocked_id IN (" + in
                + ") UNION SELECT blocker_id FROM user_block WHERE blocked_id = ? AND blocker_id IN (" + in + ")",
                Long.class, args));
        List<Object[]> kept = rows.stream().filter(r -> !skip.contains((Long) r[0])).limit(n).toList();
        if (kept.isEmpty()) {
            return List.of();
        }
        List<Long> ids = kept.stream().map(r -> (Long) r[0]).toList();
        Map<Long, PublicProfile> byId = new HashMap<>();
        profiles.mapAll(me, users.findAllById(ids)).forEach(p -> byId.put(p.id(), p));
        List<Suggestion> out = new ArrayList<>();
        for (Object[] r : kept) {
            PublicProfile p = byId.get((Long) r[0]);
            if (p != null) {
                out.add(new Suggestion(p.id(), p.displayName(), p.avatarUrl(), p.department(), (String) r[1], p.classYear()));
            }
        }
        return out;
    }

    private List<Object[]> suggestionRows(Long me) {
        long now = System.currentTimeMillis();
        synchronized (suggestionCache) {
            CachedRows c = suggestionCache.get(me);
            if (c != null && now - c.at() < SUGGESTION_TTL_MS) {
                return c.rows();
            }
        }
        List<Object[]> rows = queryCandidates(me);
        synchronized (suggestionCache) {
            suggestionCache.put(me, new CachedRows(now, rows));
        }
        return rows;
    }

    /**
     * T-024: aday kumesi "benim kulup arkadaslarim" + "ayni bolum" havuzlarina (her biri en fazla {@value #SUGGESTION_POOL})
     * daraltilir; eski sorgu butun kullanici tablosunu kulup kendi-birlesimiyle (O(kullanici x kulup^2)) tariyordu.
     * Takip/engel dislamasi kucuk bir CTE'dir (anti-join). Siralama: CLUB, GRADE, DEPARTMENT; sonra takipci sayisi, id.
     */
    private List<Object[]> queryCandidates(Long me) {
        return jdbc.query("WITH me AS (SELECT department, class_year FROM app_user WHERE id = ?), "
                + "excl AS (SELECT followee_id AS id FROM user_follow WHERE follower_id = ? "
                + "UNION SELECT blocked_id FROM user_block WHERE blocker_id = ? "
                + "UNION SELECT blocker_id FROM user_block WHERE blocked_id = ?), "
                + "club AS (SELECT u.id AS id, 0 AS tier, COALESCE(s.follower_count, 0) AS fc FROM "
                + "(SELECT DISTINCT b.user_id AS id FROM community_member a JOIN community_member b "
                + "ON b.community_id = a.community_id AND b.status = 'ACTIVE' "
                + "WHERE a.user_id = ? AND a.status = 'ACTIVE' AND b.user_id <> a.user_id) m "
                + "JOIN app_user u ON u.id = m.id AND u.status = 'ACTIVE' AND u.email_verified = TRUE "
                + "LEFT JOIN user_follow_stats s ON s.user_id = u.id "
                + "WHERE NOT EXISTS (SELECT 1 FROM excl e WHERE e.id = u.id) "
                + "ORDER BY fc DESC, u.id DESC LIMIT " + SUGGESTION_POOL + "), "
                + "dept AS (SELECT u.id AS id, CASE WHEN me.class_year IS NOT NULL AND u.class_year = me.class_year "
                + "THEN 1 ELSE 2 END AS tier, COALESCE(s.follower_count, 0) AS fc FROM me "
                + "JOIN app_user u ON me.department IS NOT NULL AND u.department = me.department AND u.id <> ? "
                + "AND u.status = 'ACTIVE' AND u.email_verified = TRUE "
                + "LEFT JOIN user_follow_stats s ON s.user_id = u.id "
                + "WHERE NOT EXISTS (SELECT 1 FROM excl e WHERE e.id = u.id) "
                + "ORDER BY tier, fc DESC, u.id DESC LIMIT " + SUGGESTION_POOL + ") "
                + "SELECT id, tier FROM (SELECT id, MIN(tier) AS tier, MAX(fc) AS fc FROM "
                + "(SELECT id, tier, fc FROM club UNION ALL SELECT id, tier, fc FROM dept) c GROUP BY id) g "
                + "ORDER BY tier, fc DESC, id DESC LIMIT " + SUGGESTION_CACHE_ROWS,
                (rs, i) -> new Object[] {rs.getLong(1), switch (rs.getInt(2)) {
                    case 0 -> "CLUB";
                    case 1 -> "GRADE";
                    default -> "DEPARTMENT";
                }}, me, me, me, me, me, me);
    }

    // ---------------------------------------------------------------- KVKK

    /** Hesap silme: iki yonlu takipler kalkar, karsi tarafin sayaclari duser. */
    @Transactional
    public void purgeUser(Long uid) {
        jdbc.update("UPDATE user_follow_stats SET follower_count = CASE WHEN follower_count > 0 THEN follower_count - 1 ELSE 0 END "
                + "WHERE user_id IN (SELECT followee_id FROM user_follow WHERE follower_id = ?)", uid);
        jdbc.update("UPDATE user_follow_stats SET following_count = CASE WHEN following_count > 0 THEN following_count - 1 ELSE 0 END "
                + "WHERE user_id IN (SELECT follower_id FROM user_follow WHERE followee_id = ?)", uid);
        jdbc.update("DELETE FROM user_follow WHERE follower_id = ? OR followee_id = ?", uid, uid);
        jdbc.update("DELETE FROM user_follow_stats WHERE user_id = ?", uid);
    }

    /** Engelleme: iki taraf arasindaki takipler kaldirilir (cagiran: moderasyon, istege bagli). */
    @Transactional
    public void dropBetween(Long a, Long b) {
        unfollow(a, b);
        unfollow(b, a);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
    }

    private static void afterCommit(Runnable r) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    r.run();
                }
            });
        } else {
            r.run();
        }
    }
}
