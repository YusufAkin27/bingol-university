package edu.bingol.backend.post.save;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.post.save.PostSaveService.SaveState;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Gonderi/reel kaydetme (KS-BE2): idempotentlik, sayac, gorunurluk, sayfalama, savedByMe (H2). */
@SpringBootTest
class PostSaveServiceTest {

    @Autowired PostSaveService service;
    @Autowired PostService postService;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired JdbcTemplate jdbc;

    private User user(String name) {
        User u = new User();
        u.setEmail(name + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private Post post(User author) {
        return PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "foto");
    }

    @Test
    void saveIsIdempotentAndCountsAndUnsaves() {
        User author = user("yazar");
        User a = user("ali");
        User b = user("veli");
        Post p = post(author);

        SaveState s1 = service.save(a.getId(), p.getId());
        SaveState s2 = service.save(a.getId(), p.getId());
        assertTrue(s1.saved());
        assertEquals(1, s1.saveCount());
        assertEquals(1, s2.saveCount());
        assertEquals(2, service.save(b.getId(), p.getId()).saveCount());

        assertTrue(postService.get(a.getId(), p.getId()).savedByMe());
        assertTrue(postService.get(b.getId(), p.getId()).savedByMe());
        assertFalse(postService.get(author.getId(), p.getId()).savedByMe(), "kaydetme kisiye ozeldir");

        SaveState u1 = service.unsave(a.getId(), p.getId());
        SaveState u2 = service.unsave(a.getId(), p.getId());
        assertFalse(u1.saved());
        assertEquals(1, u1.saveCount());
        assertEquals(1, u2.saveCount());
        assertFalse(postService.get(a.getId(), p.getId()).savedByMe());
    }

    @Test
    void invisiblePostCannotBeSavedButCanStillBeUnsaved() {
        User author = user("yazar");
        User a = user("ali");
        Post p = post(author);
        service.save(a.getId(), p.getId());
        p.setHiddenAt(Instant.now());
        posts.save(p);

        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class, () -> service.save(a.getId(), p.getId())).code());
        assertTrue(service.saved(a.getId(), null, 10).items().isEmpty(), "gizlenen gonderi listede gorunmez");
        assertFalse(service.unsave(a.getId(), p.getId()).saved());
    }

    @Test
    void savedListIsNewestFirstPagedAndFiltersBlockedAuthors() {
        User author = user("yazar");
        User blocked = user("engelli");
        User a = user("ali");
        List<Post> mine = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            Post p = post(author);
            mine.add(p);
            service.save(a.getId(), p.getId());
            // kaydetme zamanlari ayirt edilsin (H2 zaman cozunurlugu)
            jdbc.update("UPDATE post_save SET created_at = ? WHERE user_id = ? AND post_id = ?",
                    java.sql.Timestamp.from(Instant.now().minusSeconds(100 - i * 10L)), a.getId(), p.getId());
        }
        Post blockedPost = post(blocked);
        service.save(a.getId(), blockedPost.getId());
        blocks.save(new UserBlock(a.getId(), blocked.getId()));

        FeedPage p1 = service.saved(a.getId(), null, 2);
        assertEquals(2, p1.items().size());
        assertNotNull(p1.nextCursor());
        assertEquals(mine.get(4).getId(), p1.items().get(0).id(), "en son kaydedilen once");
        FeedPage p2 = service.saved(a.getId(), p1.nextCursor(), 2);
        FeedPage p3 = service.saved(a.getId(), p2.nextCursor(), 2);
        assertNull(p3.nextCursor());
        Set<Long> seen = new HashSet<>();
        for (FeedPage pg : List.of(p1, p2, p3)) {
            for (PostView v : pg.items()) {
                assertTrue(seen.add(v.id()), "tekrar yok");
                assertTrue(v.savedByMe());
            }
        }
        assertEquals(5, seen.size());
        assertFalse(seen.contains(blockedPost.getId()), "engellenen yazarin gonderisi listelenmez");
        assertEquals("POST_CURSOR_INVALID", assertThrows(ApiException.class, () -> service.saved(a.getId(), "zz", 10)).code());
    }
}
