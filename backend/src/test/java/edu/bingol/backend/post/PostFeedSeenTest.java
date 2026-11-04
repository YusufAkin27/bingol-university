package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.feed.FeedSeenService;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.post.reels.PostWatch;
import edu.bingol.backend.post.reels.PostWatchId;
import edu.bingol.backend.post.reels.PostWatchRepository;
import edu.bingol.backend.post.reels.ReelsService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Keşfet: tekrar göstermeme (görülmüş kümesi), tükenince tekrar modu (exhausted), Reels ve video izlenme olayı.
 * Her test boş bir gönderi havuzunda çalışır (havuz tamamen kontrol altında).
 */
@SpringBootTest
class PostFeedSeenTest {

    @Autowired PostService service;
    @Autowired PostRepository posts;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired UserRepository users;
    @Autowired PostRankService rank;
    @Autowired FeedSeenService seen;
    @Autowired JdbcTemplate jdbc;
    @Autowired ReelsService reelsService;
    @Autowired PostWatchRepository watchRepo;

    @BeforeEach
    void emptyPool() {
        jdbc.update("DELETE FROM post_watch");
        jdbc.update("DELETE FROM post_media");
        jdbc.update("DELETE FROM post");
    }

    /** Her biri ayri yazardan n video (begeni 50, 40, ...). */
    private List<Post> videos(int n) {
        List<Post> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            Post v = PostFixtures.withVideo(posts, mediaRepo, newUser().getId(), "v" + i);
            v.setLikeCount(50 - i * 10);
            out.add(posts.saveAndFlush(v));
        }
        rank.recompute();
        return out;
    }

    private User newUser() {
        User u = new User();
        u.setEmail("s" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Test Kullanici");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    /** Her biri ayrı yazardan, begeni sayıları 100, 90, ... : sıralama belirgindir. */
    private List<Post> photos(int n) {
        List<Post> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            Post p = PostFixtures.withPhoto(posts, mediaRepo, newUser().getId(), "p" + i);
            p.setLikeCount(100 - i * 10);
            out.add(posts.saveAndFlush(p));
        }
        rank.recompute();
        return out;
    }

    private static List<Long> ids(FeedPage p) {
        return p.items().stream().map(PostView::id).toList();
    }

    private static List<Long> ids(List<Post> ps, int from, int to) {
        return ps.subList(from, to).stream().map(Post::getId).toList();
    }

    @Test
    void refreshDoesNotRepeatSeenPostsAndRecyclesOldestSeenWhenPoolIsExhausted() throws Exception {
        User viewer = newUser();
        List<Post> ps = photos(5);

        FeedPage a = service.feed(viewer.getId(), "top", null, 3);
        assertEquals(ids(ps, 0, 3), ids(a));
        assertEquals(Boolean.FALSE, a.exhausted());
        assertNotNull(a.nextCursor());
        Thread.sleep(3);

        // yenile (imleç yok): ilk uc tekrar GELMEZ, kalan ikisi gelir
        FeedPage b = service.feed(viewer.getId(), "top", null, 3);
        assertEquals(ids(ps, 3, 5), ids(b));
        assertEquals(Boolean.FALSE, b.exhausted());
        assertNull(b.nextCursor());
        Thread.sleep(3);

        // havuz tukendi: en eski gorulmuslerden tekrar, exhausted=true, bos akis yok
        FeedPage c = service.feed(viewer.getId(), "top", null, 3);
        assertEquals(Boolean.TRUE, c.exhausted());
        assertEquals(ids(ps, 0, 3), ids(c), "en eski gorulmusler once");
        assertNotNull(c.nextCursor());

        // ayni tekrar gezintisinde sayfa 2: kalanlar, tekrar yok
        FeedPage d = service.feed(viewer.getId(), "top", c.nextCursor(), 3);
        assertEquals(Boolean.TRUE, d.exhausted());
        assertEquals(ids(ps, 3, 5), ids(d));
        assertNull(d.nextCursor());
    }

    @Test
    void samePagingSessionNeverRepeats() {
        User viewer = newUser();
        photos(7);
        Set<Long> all = new HashSet<>();
        String cursor = null;
        for (int i = 0; i < 10; i++) {
            FeedPage p = service.feed(viewer.getId(), "top", cursor, 2);
            for (Long id : ids(p)) {
                assertTrue(all.add(id), "kopya: " + id);
            }
            cursor = p.nextCursor();
            if (cursor == null) {
                break;
            }
        }
        assertEquals(7, all.size());
    }

    @Test
    void clientSeenReportExcludesPostsAndInvalidIdsAreIgnored() {
        User viewer = newUser();
        List<Post> ps = photos(4);
        service.markSeen(viewer.getId(), java.util.Arrays.asList(ps.get(0).getId(), null, -5L, 0L));
        FeedPage p = service.feed(viewer.getId(), "top", null, 10);
        assertEquals(ids(ps, 1, 4), ids(p), "bildirilen gonderi akistan haric");
        // baska kullanicinin gorulmus kumesi bagimsiz
        assertEquals(ids(ps, 0, 4), ids(service.feed(newUser().getId(), "top", null, 10)));
    }

    @Test
    void seenSetIsCappedAndForgottenOnAccountDelete() {
        User viewer = newUser();
        List<Long> many = new ArrayList<>();
        for (long i = 1; i <= 100; i++) {
            many.add(i);
        }
        seen.mark(viewer.getId(), many);
        assertEquals(100, seen.ids(viewer.getId()).size());
        seen.forget(viewer.getId());
        assertTrue(seen.ids(viewer.getId()).isEmpty());
    }

    @Test
    void recycleCursorIsValidatedAndLegacyScopesWorkUnchanged() {
        User viewer = newUser();
        photos(2);
        assertEquals("POST_CURSOR_INVALID", assertThrows(ApiException.class,
                () -> service.feed(viewer.getId(), "top", PostCursor.latest(java.time.Instant.now(), 1), 5)).code());
        FeedPage page = service.feed(viewer.getId(), "latest", null, 5);
        assertNull(page.exhausted(), "latest/popular servis kapsamlari eski davranis (exhausted yok)");
        assertEquals("foryou", FeedController.unify(null));
        assertEquals("popular", FeedController.unify("top"));
        assertEquals("popular", FeedController.unify("popular"));
        assertEquals("latest", FeedController.unify("LATEST"));
        assertEquals("following", FeedController.unify("following"));
    }

    // ------------------------------------------------------------------ reels

    @Test
    void reelsListsOnlyVideosNeverRepeatsInSessionAndSignalsExhausted() {
        User viewer = newUser();
        photos(2);
        List<Post> vids = videos(3);

        FeedPage r1 = service.reels(viewer.getId(), null, 2, false);
        assertEquals(2, r1.items().size());
        assertTrue(r1.items().stream().allMatch(v -> "VIDEO".equals(v.type()) && v.video() != null));
        assertNotNull(r1.nextCursor());
        assertEquals(Boolean.FALSE, r1.exhausted());

        FeedPage r2 = service.reels(viewer.getId(), r1.nextCursor(), 2, false);
        assertEquals(1, r2.items().size());
        assertNull(r2.nextCursor());
        assertEquals(Boolean.TRUE, r2.exhausted(), "son sayfa: tukendi gostergesi");
        Set<Long> all = new HashSet<>(ids(r1));
        assertTrue(all.addAll(ids(r2)), "oturumda tekrar yok");
        assertEquals(3, all.size());
        assertEquals(vids.stream().map(Post::getId).collect(java.util.stream.Collectors.toSet()), all);
        // ardisik ayni yazar yok (her video ayri yazardan; sayfa ici + sayfa siniri)
        // ayni oturum ayni imlecle yeniden istenirse oturumda gosterilenler gelmez
        assertTrue(service.reels(viewer.getId(), r1.nextCursor(), 2, false).items().isEmpty());
    }

    @Test
    void reelsUnseenFirstExhaustedThenReplayWithPenalties() throws Exception {
        User viewer = newUser();
        List<Post> vids = videos(3);
        List<Long> all = vids.stream().map(Post::getId).toList();
        // istemci uc videoyu da ekranda gordu: gosterim kaydi
        service.markSeen(viewer.getId(), all);
        // hizli gecme: ilk video 300 ms izlendi (sure 20 sn)
        reelsService.recordWatch(viewer.getId(), all.get(0), 300, 20_000);
        reelsService.recordWatch(viewer.getId(), all.get(0), 400, 20_000); // iki hizli gecme: ceza 2.0 > rastgelelik 1.0
        // ikincisi sonuna kadar izlendi
        reelsService.recordWatch(viewer.getId(), all.get(1), 20_000, 20_000);

        // yenileme (yeni oturum): hepsi gorulmus -> tukendi, bos akis + exhausted
        FeedPage fresh = service.reels(viewer.getId(), null, 8, false);
        assertTrue(fresh.items().isEmpty());
        assertNull(fresh.nextCursor());
        assertEquals(Boolean.TRUE, fresh.exhausted());

        // Tekrar izle: gecmisi yok sayar, hepsi gelir; hizli gecilen en sonda (ceza), son sayfada exhausted=true
        FeedPage replay = service.reels(viewer.getId(), null, 8, true);
        assertEquals(3, replay.items().size());
        assertEquals(Boolean.TRUE, replay.exhausted());
        assertEquals(all.get(0), replay.items().get(2).id(), "hizli gecilen video sona");
        assertNull(replay.nextCursor());

        // gecmis kaydi alanlari
        PostWatch w = watchRepo.findById(new PostWatchId(viewer.getId(), all.get(1))).orElseThrow();
        assertEquals(20_000, w.getWatchMs());
        assertEquals(100, w.getCompletionPct());
        assertEquals(0, w.getSkips());
        assertEquals(1, w.getImpressions());
        PostWatch s = watchRepo.findById(new PostWatchId(viewer.getId(), all.get(0))).orElseThrow();
        assertEquals(2, s.getSkips());
        // fotograf kimlikleri gosterim kaydina yazilmaz
        Post photo = PostFixtures.withPhoto(posts, mediaRepo, newUser().getId(), "foto");
        service.markSeen(viewer.getId(), List.of(photo.getId()));
        assertTrue(watchRepo.findById(new PostWatchId(viewer.getId(), photo.getId())).isEmpty());
    }

    @Test
    void notInterestedRemovesFromReelsEvenOnReplayAndCanBeUndone() {
        User viewer = newUser();
        List<Post> vids = videos(3);
        Long hidden = vids.get(1).getId();
        reelsService.setNotInterested(viewer.getId(), hidden, true);
        assertFalse(ids(service.reels(viewer.getId(), null, 8, false)).contains(hidden));
        assertFalse(ids(service.reels(viewer.getId(), null, 8, true)).contains(hidden), "tekrar modunda da hariç");
        reelsService.setNotInterested(viewer.getId(), hidden, false);
        assertTrue(ids(service.reels(viewer.getId(), null, 8, false)).contains(hidden));
    }

    @Test
    void reelsRankingPrefersFollowedAndLikedAuthorsAndRefreshReshuffles() {
        User viewer = newUser();
        User followed = newUser();
        Post fv = PostFixtures.withVideo(posts, mediaRepo, followed.getId(), "takip");
        fv.setLikeCount(50);
        posts.saveAndFlush(fv);
        jdbc.update("INSERT INTO user_follow (follower_id, followee_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                viewer.getId(), followed.getId());
        videos(5);
        // tohum degisse de takip bonusu (1.2) rastgeleligi (<=1.0) yener: takip edilen ilk sirada
        for (int i = 0; i < 5; i++) {
            assertEquals(fv.getId(), service.reels(viewer.getId(), null, 8, false).items().get(0).id());
        }
        // kontrollu yeniden uretim: baska oturumlarda farkli tohum -> en az bir kez farkli ilk video (takipsiz kullanici)
        User other = newUser();
        Set<Long> firsts = new HashSet<>();
        for (int i = 0; i < 25; i++) {
            firsts.add(service.reels(other.getId(), null, 8, false).items().get(0).id());
        }
        assertTrue(firsts.size() > 1, "yenileme ayni videoyu hep ilk getirmez");
    }

    @Test
    void forYouPrefersFollowedAuthorsKeepsSessionOrderAndExcludesSeen() {
        User viewer = newUser();
        List<Post> ps = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            ps.add(PostFixtures.withPhoto(posts, mediaRepo, newUser().getId(), "p" + i));
        }
        rank.recompute();
        Post followedPost = ps.get(5);
        jdbc.update("INSERT INTO user_follow (follower_id, followee_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                viewer.getId(), followedPost.getAuthorId());
        FeedPage p1 = service.feed(viewer.getId(), "foryou", null, 3);
        assertEquals(followedPost.getId(), p1.items().get(0).id(), "takip edilen yazar once");
        assertEquals(Boolean.FALSE, p1.exhausted());
        assertNotNull(p1.nextCursor());
        FeedPage p2 = service.feed(viewer.getId(), "foryou", p1.nextCursor(), 3);
        assertEquals(3, p2.items().size());
        Set<Long> seenIds = new HashSet<>(ids(p1));
        assertTrue(java.util.Collections.disjoint(seenIds, ids(p2)), "ayni oturumda tekrar yok");
        assertNull(p2.nextCursor());
        // havuz tukendi: tekrar modu (exhausted)
        assertEquals(Boolean.TRUE, service.feed(viewer.getId(), "foryou", null, 3).exhausted());
        // popular ve latest kapsamlari calisir; gecersiz 400
        assertFalse(service.feed(newUser().getId(), "popular", null, 5).items().isEmpty());
        assertFalse(service.feed(newUser().getId(), "latest", null, 5).items().isEmpty());
        assertEquals("FEED_SCOPE_INVALID", assertThrows(ApiException.class,
                () -> service.feed(viewer.getId(), "bogus", null, 5)).code());
        assertEquals("POST_CURSOR_INVALID", assertThrows(ApiException.class,
                () -> service.feed(viewer.getId(), "foryou", "bozuk", 5)).code());
    }

    @Test
    void feedMixesPhotosAndVideosAndTypesThem() {
        User viewer = newUser();
        Post photo = PostFixtures.withPhoto(posts, mediaRepo, newUser().getId(), "foto");
        Post video = PostFixtures.withVideo(posts, mediaRepo, newUser().getId(), "video");
        rank.recompute();
        FeedPage page = service.feed(viewer.getId(), "top", null, 10);
        PostView vp = page.items().stream().filter(v -> v.id().equals(video.getId())).findFirst().orElseThrow();
        PostView pp = page.items().stream().filter(v -> v.id().equals(photo.getId())).findFirst().orElseThrow();
        assertEquals("VIDEO", vp.type());
        assertEquals(20_000, vp.video().durationMs());
        assertEquals(720, vp.video().width());
        assertTrue(vp.video().url().startsWith("/api/posts/media/"));
        assertEquals(0, vp.viewCount());
        assertEquals("PHOTO", pp.type());
        assertNull(pp.video());
        assertNotNull(pp.popularityScore());
        assertNotNull(vp.author().popularityScore());
        assertNotNull(vp.author().followerCount());
    }

    // ------------------------------------------------------------------ izlenme

    @Test
    void viewCountsOncePerUserIgnoresOwnPhotoAndTooShortAndFeedsRank() {
        User author = newUser();
        User viewer = newUser();
        Post video = PostFixtures.withVideo(posts, mediaRepo, author.getId(), "izle"); // sunucu suresi 20 sn
        Post photo = PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "foto");

        assertFalse(service.recordView(viewer.getId(), video.getId(), 500, 20_000), "1 sn'den kisa sayilmaz");
        assertTrue(service.recordView(viewer.getId(), video.getId(), 10_000, 999), "sunucu suresi esas: %50");
        assertFalse(service.recordView(viewer.getId(), video.getId(), 20_000, 20_000), "ayni kullanici tekrar sayilmaz");
        assertFalse(service.recordView(author.getId(), video.getId(), 20_000, 20_000), "kendi videosu sayilmaz");
        assertFalse(service.recordView(viewer.getId(), photo.getId(), 20_000, 20_000), "fotograf izlenmez");
        User v2 = newUser();
        assertTrue(service.recordView(v2.getId(), video.getId(), 90_000, 0), "tamamlanma %100'e kenetlenir");

        Post p = posts.findById(video.getId()).orElseThrow();
        assertEquals(2, p.getViewCount());
        assertEquals(150, p.getCompletionPctSum(), "50 + 100");
        assertEquals(0.75, p.avgCompletion(), 1e-9);
        assertEquals(2, service.get(viewer.getId(), video.getId()).viewCount());
        assertEquals("POST_NOT_FOUND", assertThrows(ApiException.class,
                () -> service.recordView(viewer.getId(), 987654321L, 5000, 5000)).code());

        // puana girer: izlenen video, ayni begenideki izlenmemisten yuksek
        Post idle = PostFixtures.withVideo(posts, mediaRepo, newUser().getId(), "sessiz");
        rank.recompute();
        assertTrue(posts.findById(video.getId()).orElseThrow().getRankScore()
                > posts.findById(idle.getId()).orElseThrow().getRankScore());
    }
}
