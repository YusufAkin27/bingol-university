package edu.bingol.backend.post.social;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostCursor;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.PostViewAssembler;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Gonderi kaydetme: yalniz kaydedenin kendi listesi (sayac ve baskasina gorunurluk yok). */
@Service
public class PostSaveService {

    private final PostService posts;
    private final PostRepository postRepo;
    private final PostSaveRepository saves;
    private final PostViewAssembler assembler;
    private final JdbcTemplate jdbc;

    public PostSaveService(PostService posts, PostRepository postRepo, PostSaveRepository saves,
                           PostViewAssembler assembler, JdbcTemplate jdbc) {
        this.posts = posts;
        this.postRepo = postRepo;
        this.saves = saves;
        this.assembler = assembler;
        this.jdbc = jdbc;
    }

    /** Idempotent. Gorunmeyen gonderi 404 POST_NOT_FOUND. */
    @Transactional
    public void save(Long uid, Long postId) {
        posts.requireVisible(postId, uid);
        jdbc.update("INSERT INTO post_save (user_id, post_id, created_at) SELECT ?, ?, CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM post_save WHERE user_id = ? AND post_id = ?)", uid, postId, uid, postId);
    }

    /** Idempotent; gonderi artik gorunmese de kayit kaldirilabilir. */
    @Transactional
    public void unsave(Long uid, Long postId) {
        jdbc.update("DELETE FROM post_save WHERE user_id = ? AND post_id = ?", uid, postId);
    }

    @Transactional(readOnly = true)
    public FeedPage list(Long uid, String cursor, int size) {
        int n = size <= 0 ? 10 : Math.min(size, 20);
        PostCursor c = PostCursor.decode(cursor, 'L');
        List<PostSave> rows = c == null ? saves.first(uid, PageRequest.of(0, n + 1))
                : saves.after(uid, c.at(), c.id(), PageRequest.of(0, n + 1));
        boolean more = rows.size() > n;
        List<PostSave> page = more ? rows.subList(0, n) : rows;
        Map<Long, Post> byId = new HashMap<>();
        postRepo.findAllById(page.stream().map(s -> s.getId().getB()).toList()).forEach(p -> byId.put(p.getId(), p));
        List<Post> ordered = new ArrayList<>();
        for (PostSave s : page) {
            Post p = byId.get(s.getId().getB());
            if (p != null) {
                ordered.add(p);
            }
        }
        String next = null;
        if (more) {
            PostSave last = page.get(page.size() - 1);
            next = PostCursor.latest(last.getCreatedAt(), last.getId().getB());
        }
        return new FeedPage(assembler.assemble(uid, ordered), next);
    }

    /** KVKK/hesap silme. */
    @Transactional
    public int purgeUser(Long uid) {
        return jdbc.update("DELETE FROM post_save WHERE user_id = ?", uid);
    }
}
