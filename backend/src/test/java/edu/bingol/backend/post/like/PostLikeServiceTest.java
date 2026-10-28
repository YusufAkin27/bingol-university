package edu.bingol.backend.post.like;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.like.PostLikeDtos.LikeState;
import edu.bingol.backend.post.like.PostLikeDtos.Liker;
import edu.bingol.backend.post.like.PostLikeDtos.LikersPage;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Beğeni servisi: idempotentlik, yarış, sayaç tutarlılığı, görünürlük/engel, sayfalama, KVKK temizliği (H2). */
@SpringBootTest
class PostLikeServiceTest {

    @Autowired PostLikeService service;
    @Autowired PostLikeRepository likes;
    @Autowired PostRepository posts;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;

    private User user(String name) {
        User u = new User();
        u.setEmail(name + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private Post post(User author) {
        Post p = new Post();
        p.setAuthorId(author.getId());
        p.setBody("merhaba");
        return posts.save(p);
    }

    private int count(Post p) {
        return posts.findById(p.getId()).orElseThrow().getLikeCount();
    }

    @Test
    void likeIsIdempotentAndCounterConsistent() {
        User a = user("yazar");
        User b = user("okur");
        Post p = post(a);
        LikeState s1 = service.like(b.getId(), p.getId());
        LikeState s2 = service.like(b.getId(), p.getId());
        assertTrue(s1.liked());
        assertEquals(1, s1.likeCount());
        assertEquals(1, s2.likeCount());
        assertEquals(1, count(p));

        LikeState u1 = service.unlike(b.getId(), p.getId());
        LikeState u2 = service.unlike(b.getId(), p.getId());
        assertFalse(u1.liked());
        assertEquals(0, u1.likeCount());
        assertEquals(0, u2.likeCount());
        assertEquals(0, count(p));
    }

    @Test
    void ownPostCanBeLiked() {
        User a = user("kendi");
        Post p = post(a);
        assertEquals(1, service.like(a.getId(), p.getId()).likeCount());
    }

    @Test
    void concurrentDoublePutCountsOnce() throws Exception {
        User a = user("yazar");
        User b = user("yarisci");
        Post p = post(a);
        int n = 8;
        ExecutorService ex = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<LikeState>> fs = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            fs.add(ex.submit(() -> {
                go.await();
                return service.like(b.getId(), p.getId());
            }));
        }
        go.countDown();
        for (Future<LikeState> f : fs) {
            assertTrue(f.get().liked()); // hiçbiri hata fırlatmaz
        }
        ex.shutdown();
        assertTrue(ex.awaitTermination(10, java.util.concurrent.TimeUnit.SECONDS));
        assertEquals(1, count(p));
        assertEquals(1, likes.findAll().stream().filter(l -> l.getId().getPostId().equals(p.getId())).count());
    }

    @Test
    void hiddenDeletedMissingOrBlockedPostIs404() {
        User a = user("yazar");
        User b = user("okur");
        Post hidden = post(a);
        hidden.setHiddenAt(Instant.now());
        posts.save(hidden);
        Post deleted = post(a);
        deleted.setDeletedAt(Instant.now());
        posts.save(deleted);
        for (Long id : new Long[] {hidden.getId(), deleted.getId(), 999_999L}) {
            ApiException e = assertThrows(ApiException.class, () -> service.like(b.getId(), id));
            assertEquals("POST_NOT_FOUND", e.code());
            assertThrows(ApiException.class, () -> service.unlike(b.getId(), id));
            assertThrows(ApiException.class, () -> service.listLikers(id, b.getId(), null, 10));
        }
        Post p = post(a);
        blocks.save(new UserBlock(a.getId(), b.getId()));
        assertThrows(ApiException.class, () -> service.like(b.getId(), p.getId()));
    }

    @Test
    void likersPagingTotalAndBlockedHidden() {
        User a = user("yazar");
        Post p = post(a);
        User viewer = user("bakan");
        User blockedLiker = user("engelli");
        List<User> others = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            User u = user("k" + i);
            others.add(u);
            service.like(u.getId(), p.getId());
        }
        service.like(blockedLiker.getId(), p.getId());
        blocks.save(new UserBlock(viewer.getId(), blockedLiker.getId()));

        LikersPage first = service.listLikers(p.getId(), viewer.getId(), null, 2);
        assertEquals(2, first.items().size());
        assertNotNull(first.nextCursor());
        assertEquals(5, first.total()); // engelli sayılmaz

        Set<Long> seen = new HashSet<>();
        String cursor = null;
        int pages = 0;
        do {
            LikersPage pg = service.listLikers(p.getId(), viewer.getId(), cursor, 2);
            for (Liker l : pg.items()) {
                assertTrue(seen.add(l.id()), "tekrar eden kayıt");
                assertNotNull(l.likedAt());
            }
            cursor = pg.nextCursor();
            pages++;
        } while (cursor != null && pages < 10);
        assertEquals(3, pages);
        assertEquals(5, seen.size());
        assertFalse(seen.contains(blockedLiker.getId()));
        assertTrue(seen.containsAll(others.stream().map(User::getId).toList()));

        // size üst sınırı 30
        assertEquals(5, service.listLikers(p.getId(), viewer.getId(), null, 500).items().size());
        ApiException bad = assertThrows(ApiException.class,
                () -> service.listLikers(p.getId(), viewer.getId(), "bozuk", 10));
        assertEquals("POST_CURSOR_INVALID", bad.code());
    }

    @Test
    void likedPostIdsIsBatchedPerViewer() {
        User a = user("yazar");
        User b = user("okur");
        Post p1 = post(a);
        Post p2 = post(a);
        Post p3 = post(a);
        service.like(b.getId(), p1.getId());
        service.like(b.getId(), p3.getId());
        service.like(a.getId(), p2.getId());
        assertEquals(Set.of(p1.getId(), p3.getId()),
                service.likedPostIds(b.getId(), List.of(p1.getId(), p2.getId(), p3.getId())));
        assertTrue(service.likedPostIds(b.getId(), List.of()).isEmpty());
        assertTrue(service.likedPostIds(null, List.of(p1.getId())).isEmpty());
    }

    @Test
    void purgeUserDeletesLikesAndDecrementsCounters() {
        User a = user("yazar");
        User b = user("silinen");
        User c = user("kalan");
        Post p1 = post(a);
        Post p2 = post(a);
        service.like(b.getId(), p1.getId());
        service.like(c.getId(), p1.getId());
        service.like(b.getId(), p2.getId());
        assertEquals(2, count(p1));

        assertEquals(2, service.purgeUser(b.getId()));
        assertEquals(1, count(p1));
        assertEquals(0, count(p2));
        assertTrue(service.likedPostIds(b.getId(), List.of(p1.getId(), p2.getId())).isEmpty());
        assertEquals(0, service.purgeUser(b.getId()));
    }
}
