package edu.bingol.backend.post.popularity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.post.popularity.UserPopularityService.Snapshot;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Kullanıcı popülerlik puanı: saf formül + toplu iş + okuma (satır / anında hesap) + silme. */
@SpringBootTest
class UserPopularityTest {

    private static final PopularityProperties P = new PopularityProperties(500, 2000, 60, 0.45, 0.40, 0.15, 3_600_000, 500);

    @Autowired UserPopularityService service;
    @Autowired UserPopularityRepository repo;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    @Test
    void formulaIsBoundedMonotonicAndLogScaled() {
        assertEquals(0, UserPopularityService.score(P, 0, 0, 0));
        assertEquals(100, UserPopularityService.score(P, 500, 2000, 60), "tum bilesenler tavanda = 100");
        assertEquals(100, UserPopularityService.score(P, 10_000_000, 90_000_000, 9_000), "tavan ustu kenetlenir");
        int a = UserPopularityService.score(P, 10, 0, 0);
        int b = UserPopularityService.score(P, 100, 0, 0);
        int c = UserPopularityService.score(P, 100, 500, 0);
        int d = UserPopularityService.score(P, 100, 500, 20);
        assertTrue(0 < a && a < b && b < c && c < d && d < 100);
        // log olcek: +10 takipci dusuk tabanda cok daha degerli
        int low = UserPopularityService.score(P, 10, 0, 0) - UserPopularityService.score(P, 0, 0, 0);
        int high = UserPopularityService.score(P, 410, 0, 0) - UserPopularityService.score(P, 400, 0, 0);
        assertTrue(low > high * 5);
        // ayni girdi ayni puan (deterministik) ve agirliklar toplami 0 ise 0
        assertEquals(UserPopularityService.score(P, 7, 9, 3), UserPopularityService.score(P, 7, 9, 3));
        assertEquals(0, UserPopularityService.score(new PopularityProperties(500, 2000, 60, 0, 0, 0, 1, 50), 500, 2000, 60));
    }

    private User newUser() {
        User u = new User();
        u.setEmail("u" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Test Kullanici");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    @Test
    void recomputeCountsOnlyVisiblePostsAndRealFollowersAndLikes() {
        User a = newUser();
        Post p1 = PostFixtures.withPhoto(posts, mediaRepo, a.getId(), "bir");
        p1.setLikeCount(10);
        posts.saveAndFlush(p1);
        Post p2 = PostFixtures.withVideo(posts, mediaRepo, a.getId(), "iki");
        p2.setLikeCount(30);
        posts.saveAndFlush(p2);
        Post hidden = PostFixtures.withPhoto(posts, mediaRepo, a.getId(), "gizli");
        hidden.setLikeCount(1000);
        hidden.setHiddenAt(Instant.now());
        posts.saveAndFlush(hidden);
        Post deleted = PostFixtures.withPhoto(posts, mediaRepo, a.getId(), "silinmis");
        deleted.setLikeCount(1000);
        deleted.setDeletedAt(Instant.now());
        posts.saveAndFlush(deleted);
        jdbc.update("INSERT INTO user_follow_stats (user_id, follower_count, following_count) VALUES (?, ?, 0)",
                a.getId(), 40);

        // satir yokken: anında hesap (yazmaz)
        Snapshot live = service.of(a.getId());
        assertEquals(40, live.followerCount());
        assertEquals(40L, live.likesReceived());
        assertEquals(2, live.postCount());
        assertEquals(UserPopularityService.score(P, 40, 40, 2), live.score());
        assertTrue(repo.findById(a.getId()).isEmpty());

        service.recomputeAll();
        UserPopularity row = repo.findById(a.getId()).orElseThrow();
        assertEquals(live.score(), row.getScore());
        assertEquals(40, row.getFollowerCount());
        assertEquals(40L, row.getLikesReceived());
        assertEquals(2, row.getPostCount());
        assertEquals(live, service.of(a.getId()));

        // sayilar degisince is yeniden yazar; yazma yok degisimi: computedAt ayni kalir
        Instant before = row.getComputedAt();
        service.recomputeAll();
        assertEquals(before, repo.findById(a.getId()).orElseThrow().getComputedAt(), "degismeyen satir yeniden yazilmaz");
        p1.setLikeCount(110);
        posts.saveAndFlush(p1);
        service.recomputeAll();
        assertEquals(140L, repo.findById(a.getId()).orElseThrow().getLikesReceived());

        // toplu okuma: satiri olan + olmayan
        User fresh = newUser();
        var map = service.forUsers(List.of(a.getId(), fresh.getId()));
        assertEquals(140L, map.get(a.getId()).likesReceived());
        assertEquals(Snapshot.ZERO, map.get(fresh.getId()));

        // KVKK: hesap silinince satir kalkar
        service.purge(a.getId());
        assertTrue(repo.findById(a.getId()).isEmpty());
    }
}
