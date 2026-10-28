package edu.bingol.backend.post.like;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.PostCounters;
import edu.bingol.backend.post.like.PostLikeDtos.LikeState;
import edu.bingol.backend.post.like.PostLikeDtos.Liker;
import edu.bingol.backend.post.like.PostLikeDtos.LikersPage;
import edu.bingol.backend.post.notify.PostNotifier;
import edu.bingol.backend.post.spi.PostLikeLookup;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Gönderi beğenileri. Beğeni satırı + sayaç aynı transaction'da; eş zamanlı çift PUT'ta unique ihlali yutulur
 * (transaction dışında yakalanır: Hibernate oturumu ihlalden sonra kullanılamaz).
 */
@Service
public class PostLikeService implements PostLikeLookup {

    private static final Logger log = LoggerFactory.getLogger(PostLikeService.class);
    static final int MAX_SIZE = 30;
    private static final Set<Long> NO_HIDDEN = Set.of(-1L);

    private final PostLikeRepository likes;
    private final PostCounters counters;
    private final BlockService blocks;
    private final UserRepository users;
    private final PublicProfileMapper profiles;
    private final PostNotifier notifier;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;

    public PostLikeService(PostLikeRepository likes, PostCounters counters, BlockService blocks, UserRepository users,
                           PublicProfileMapper profiles, PostNotifier notifier, JdbcTemplate jdbc,
                           PlatformTransactionManager tm) {
        this.likes = likes;
        this.counters = counters;
        this.blocks = blocks;
        this.users = users;
        this.profiles = profiles;
        this.notifier = notifier;
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(tm);
    }

    /** Idempotent beğeni. Gönderi görünür değilse 404 POST_NOT_FOUND. */
    public LikeState like(Long userId, Long postId) {
        Long authorId = authorOrThrow(postId, userId);
        boolean added = false;
        // Eş zamanlı çift PUT: ikinci işlem unique ihlali (PG/H2) ya da kilit/eşzamanlılık hatası (H2 MVCC) alabilir.
        // Satır başka işlem tarafından eklenmişse sonuç "zaten beğenilmiş"tir; eklenmemişse bir kez yeniden denenir.
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                added = Boolean.TRUE.equals(tx.execute(st -> insertLike(userId, postId)));
                break;
            } catch (DataIntegrityViolationException | ConcurrencyFailureException e) {
                if (likeExists(userId, postId)) {
                    added = false; // sayaç, satırı ekleyen ilk istekte arttı
                    break;
                }
                if (attempt == 2) {
                    throw e;
                }
            }
        }
        if (added) {
            try {
                notifier.onLike(userId, postId, authorId);
            } catch (RuntimeException e) {
                log.warn("Begeni bildirimi atlandi (gonderi {}): {}", postId, e.toString());
            }
        }
        return new LikeState(true, counters.likeCount(postId));
    }

    /** Atomik: satır gerçekten eklendiyse sayaç artar. (saveAndFlush = merge: çift sayardı.) */
    private boolean insertLike(Long userId, Long postId) {
        int n = jdbc.update("INSERT INTO post_like (post_id, user_id, created_at) SELECT ?, ?, CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM post_like WHERE post_id = ? AND user_id = ?)",
                postId, userId, postId, userId);
        if (n == 0) {
            return false;
        }
        counters.incrementLikes(postId, 1);
        return true;
    }

    private boolean likeExists(Long userId, Long postId) {
        Integer c = jdbc.queryForObject("SELECT COUNT(*) FROM post_like WHERE post_id = ? AND user_id = ?",
                Integer.class, postId, userId);
        return c != null && c > 0;
    }

    public LikeState unlike(Long userId, Long postId) {
        authorOrThrow(postId, userId);
        tx.executeWithoutResult(st -> {
            if (likes.deleteLike(postId, userId) > 0) {
                counters.incrementLikes(postId, -1);
            }
        });
        return new LikeState(false, counters.likeCount(postId));
    }

    /** Beğenenler, yeniden eskiye; engel ilişkisindekiler gizli, avatar gizlilik kuralına tabi. */
    public LikersPage listLikers(Long postId, Long viewerId, String cursor, int size) {
        authorOrThrow(postId, viewerId);
        int n = Math.min(Math.max(size, 1), MAX_SIZE);
        Set<Long> hidden = blocks.hiddenFrom(viewerId);
        Collection<Long> hid = hidden.isEmpty() ? NO_HIDDEN : hidden;
        PageRequest page = PageRequest.of(0, n + 1);
        List<PostLike> rows;
        if (cursor == null || cursor.isBlank()) {
            rows = likes.likersFirst(postId, hid, page);
        } else {
            Object[] c = parseCursor(cursor);
            rows = likes.likersAfter(postId, hid, (Instant) c[0], (Long) c[1], page);
        }
        boolean more = rows.size() > n;
        List<PostLike> pageRows = more ? rows.subList(0, n) : rows;
        Map<Long, User> byId = users.findAllById(pageRows.stream().map(l -> l.getId().getUserId()).toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<User> ordered = new ArrayList<>();
        for (PostLike l : pageRows) {
            ordered.add(byId.get(l.getId().getUserId()));
        }
        List<PublicProfile> profs = ordered.isEmpty() ? List.of() : profiles.mapAll(viewerId, ordered);
        List<Liker> items = new ArrayList<>();
        for (int i = 0; i < pageRows.size(); i++) {
            PublicProfile p = profs.get(i);
            items.add(new Liker(p.id(), p.displayName(), p.avatarUrl(), pageRows.get(i).getCreatedAt()));
        }
        String next = more ? cursorOf(pageRows.get(pageRows.size() - 1)) : null;
        return new LikersPage(items, next, likes.countLikers(postId, hid));
    }

    @Override
    public Set<Long> likedPostIds(Long viewerId, Collection<Long> postIds) {
        if (viewerId == null || postIds == null || postIds.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(likes.likedAmong(viewerId, postIds));
    }

    /** KVKK: kullanıcının tüm beğenileri silinir, ilgili gönderi sayaçları düşer. @return silinen beğeni sayısı */
    public int purgeUser(Long userId) {
        Integer n = tx.execute(st -> {
            jdbc.update("UPDATE post SET like_count = GREATEST(like_count - 1, 0) "
                    + "WHERE id IN (SELECT post_id FROM post_like WHERE user_id = ?)", userId);
            return jdbc.update("DELETE FROM post_like WHERE user_id = ?", userId);
        });
        return n == null ? 0 : n;
    }

    private Long authorOrThrow(Long postId, Long viewerId) {
        return likes.visibleAuthor(postId, viewerId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "POST_NOT_FOUND", "Gönderi bulunamadı."));
    }

    static String cursorOf(PostLike l) {
        Instant t = l.getCreatedAt();
        long micros = t.getEpochSecond() * 1_000_000L + t.getNano() / 1000;
        return micros + "_" + l.getId().getUserId();
    }

    static Object[] parseCursor(String cursor) {
        try {
            String[] p = cursor.split("_");
            long micros = Long.parseLong(p[0]);
            Instant t = Instant.ofEpochSecond(Math.floorDiv(micros, 1_000_000L), Math.floorMod(micros, 1_000_000L) * 1000);
            return new Object[] {t, Long.parseLong(p[1])};
        } catch (RuntimeException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POST_CURSOR_INVALID", "Geçersiz sayfa imleci.");
        }
    }
}
