package edu.bingol.backend.post.save;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.PostViewAssembler;
import edu.bingol.backend.post.spi.PostSaveLookup;
import java.time.Instant;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.springframework.dao.ConcurrencyFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Gonderi/reel kaydetme (KS-BE2): kullanici baska bir gonderiyi (kendi gonderisi dahil) kaydeder; liste yalniz kendisine
 * gorunur. Kaydetme idempotent; gonderi bakana gorunur degilse 404 POST_NOT_FOUND. Kaydi kaldirmak gorunurluge bagli degil.
 * Gonderi sonradan silinir/gizlenir/engellenirse kayit satiri kalir ama listede sessizce gorunmez.
 */
@Service
public class PostSaveService implements PostSaveLookup {

    static final int DEFAULT_SIZE = 20;
    static final int MAX_SIZE = 30;

    /** saveCount: gonderiyi kaydeden toplam kisi sayisi (yalniz bilgi; kim kaydetti gosterilmez). */
    public record SaveState(boolean saved, long saveCount) {}

    private final PostSaveRepository saves;
    private final PostService posts;
    private final PostViewAssembler assembler;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;

    public PostSaveService(PostSaveRepository saves, PostService posts, PostViewAssembler assembler, JdbcTemplate jdbc,
                           PlatformTransactionManager tm) {
        this.saves = saves;
        this.posts = posts;
        this.assembler = assembler;
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(tm);
    }

    /** Idempotent kaydet. */
    public SaveState save(Long uid, Long postId) {
        posts.requireVisible(postId, uid);
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                tx.executeWithoutResult(st -> jdbc.update("INSERT INTO post_save (user_id, post_id, created_at) "
                        + "SELECT ?, ?, CURRENT_TIMESTAMP WHERE NOT EXISTS (SELECT 1 FROM post_save WHERE user_id = ? AND post_id = ?)",
                        uid, postId, uid, postId));
                break;
            } catch (DataIntegrityViolationException | ConcurrencyFailureException e) {
                if (!saves.savedAmong(uid, List.of(postId)).isEmpty()) {
                    break; // es zamanli cift PUT: satir zaten var
                }
                if (attempt == 2) {
                    throw e;
                }
            }
        }
        return new SaveState(true, saves.countByPost(postId));
    }

    /** Kaydi kaldir (idempotent; gonderi gorunur olmasa da). */
    @Transactional
    public SaveState unsave(Long uid, Long postId) {
        saves.deleteSave(uid, postId);
        return new SaveState(false, saves.countByPost(postId));
    }

    /** Kaydedilenler (yeni kaydedilen once); size varsayilan 20, en cok 30. */
    @Transactional(readOnly = true)
    public FeedPage saved(Long viewer, String cursor, int size) {
        int n = size <= 0 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<Post> rows = c == null ? saves.savedFirst(viewer, PageRequest.of(0, n + 1))
                : saves.savedAfter(viewer, c.at(), c.id(), PageRequest.of(0, n + 1));
        boolean more = rows.size() > n;
        List<Post> items = more ? rows.subList(0, n) : rows;
        String next = null;
        if (more) {
            Post last = items.get(items.size() - 1);
            List<Instant> at = saves.savedAt(viewer, last.getId());
            next = at.isEmpty() ? null : PostCursor.latest(at.get(0), last.getId());
        }
        return new FeedPage(assembler.assemble(viewer, items), next);
    }

    @Override
    public Set<Long> savedPostIds(Long viewerId, Collection<Long> postIds) {
        if (viewerId == null || postIds == null || postIds.isEmpty()) {
            return Set.of();
        }
        return new HashSet<>(saves.savedAmong(viewerId, postIds));
    }
}
