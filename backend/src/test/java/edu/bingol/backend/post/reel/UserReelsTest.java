package edu.bingol.backend.post.reel;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.follow.FollowService;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import edu.bingol.backend.profile.privacy.PrivacyService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Profil Reels listesi + profil sayaclari (postCount/reelCount) + arama satiri takip bayraklari (KS-BE2, H2). */
@SpringBootTest
class UserReelsTest {

    @MockitoBean edu.bingol.backend.common.RateLimiter limiter;

    @Autowired UserReelsService reels;
    @Autowired ProfilePostCounts counts;
    @Autowired ProfileService profiles;
    @Autowired FollowService follow;
    @Autowired PrivacyService privacy;
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

    private Post photo(User author) {
        return PostFixtures.withPhoto(posts, mediaRepo, author.getId(), "foto");
    }

    /** Video gonderi: tek VIDEO medyali gonderi (KS-BE'nin yukleme hatti gelene dek dogrudan satir). */
    private Post video(User author) {
        Post p = new Post();
        p.setAuthorId(author.getId());
        p.setBody("reel");
        p.setMediaCount((short) 1);
        p = posts.saveAndFlush(p);
        PostFixtures.media(mediaRepo, author.getId(), p.getId(), PostMedia.VIDEO);
        return p;
    }

    @Test
    void onlyVideoPostsAreListedNewestFirstWithCursor() {
        User author = user("yazar");
        User viewer = user("izleyen");
        photo(author);
        Post v1 = video(author);
        Post v2 = video(author);
        Post v3 = video(author);
        // zaman sirasi: v1 < v2 < v3
        jdbc.update("UPDATE post SET created_at = ? WHERE id = ?", java.sql.Timestamp.from(Instant.now().minusSeconds(300)), v1.getId());
        jdbc.update("UPDATE post SET created_at = ? WHERE id = ?", java.sql.Timestamp.from(Instant.now().minusSeconds(200)), v2.getId());
        jdbc.update("UPDATE post SET created_at = ? WHERE id = ?", java.sql.Timestamp.from(Instant.now().minusSeconds(100)), v3.getId());

        FeedPage p1 = reels.byAuthor(viewer.getId(), author.getId(), null, 2);
        assertEquals(List.of(v3.getId(), v2.getId()), p1.items().stream().map(PostView::id).toList());
        assertNotNull(p1.nextCursor());
        assertEquals(Boolean.FALSE, p1.locked());
        FeedPage p2 = reels.byAuthor(viewer.getId(), author.getId(), p1.nextCursor(), 2);
        assertEquals(List.of(v1.getId()), p2.items().stream().map(PostView::id).toList());
        assertNull(p2.nextCursor());

        Set<Long> all = new HashSet<>();
        p1.items().forEach(i -> all.add(i.id()));
        p2.items().forEach(i -> all.add(i.id()));
        assertEquals(3, all.size(), "fotograf gonderi Reels listesinde yok");
    }

    @Test
    void hiddenAndBlockedAreExcluded() {
        User author = user("yazar");
        User viewer = user("izleyen");
        Post v1 = video(author);
        Post v2 = video(author);
        v1.setHiddenAt(Instant.now());
        posts.save(v1);

        assertEquals(List.of(v2.getId()), reels.byAuthor(viewer.getId(), author.getId(), null, 10).items().stream().map(PostView::id).toList());

        blocks.save(new UserBlock(viewer.getId(), author.getId()));
        assertTrue(reels.byAuthor(viewer.getId(), author.getId(), null, 10).items().isEmpty());
    }

    @Test
    void privateAccountReelsAreLockedUntilFollowAccepted() {
        User author = user("gizli");
        User viewer = user("izleyen");
        video(author);
        privacy.update(author.getId(), new UpdatePrivacyRequest(null, null, null, null, null, null, true));

        FeedPage locked = reels.byAuthor(viewer.getId(), author.getId(), null, 10);
        assertEquals(Boolean.TRUE, locked.locked());
        assertTrue(locked.items().isEmpty());
        // sahibi her zaman gorur
        assertEquals(1, reels.byAuthor(author.getId(), author.getId(), null, 10).items().size());
    }

    @Test
    void profileCountsSplitPostsAndReels() {
        User author = user("yazar");
        User viewer = user("izleyen");
        photo(author);
        photo(author);
        Post hiddenVideo = video(author);
        video(author);
        hiddenVideo.setHiddenAt(Instant.now());
        posts.save(hiddenVideo);
        // fotografsiz eski metin gonderisi sayilmaz
        PostFixtures.textOnly(posts, author.getId(), "eski");

        ProfilePostCounts.Counts c = counts.counts(author.getId());
        assertEquals(3, c.postCount());
        assertEquals(1, c.reelCount());

        PublicProfile pp = profiles.publicProfile(viewer.getId(), author.getId());
        assertNotNull(pp.postCount(), "postCount KS-BE UserPopularityService kaynaklidir (sayim kurali orada)");
        assertEquals(1L, pp.reelCount());

        // engelli cift: sabit 0 (normal profille ayirt ettirmez)
        blocks.save(new UserBlock(viewer.getId(), author.getId()));
        PublicProfile shadow = profiles.publicProfile(viewer.getId(), author.getId());
        assertEquals(0L, shadow.reelCount());
    }

    @Test
    void lockedPrivateProfileHidesCounts() {
        User author = user("gizli");
        User viewer = user("izleyen");
        photo(author);
        privacy.update(author.getId(), new UpdatePrivacyRequest(null, null, null, null, null, null, true));

        PublicProfile pp = profiles.publicProfile(viewer.getId(), author.getId());
        assertEquals(Boolean.TRUE, pp.locked());
        assertNull(pp.postCount());
        assertNull(pp.reelCount());
        // sahibi kendi sayaclarini gorur
        assertEquals(1, profiles.publicProfile(author.getId(), author.getId()).postCount());
    }

    @Test
    void searchRowsCarryFollowFlagsAndRealCounts() {
        User viewer = user("Arama Yapan");
        User followed = user("Şirin Yıldız");
        User follower = user("Çağla Yıldırım");
        User stranger = user("Ayşe Yıldızhan");
        follow.follow(viewer.getId(), followed.getId());
        follow.follow(follower.getId(), viewer.getId());

        var res = profiles.search(viewer.getId(), "YILDIZ", 20, null);
        var byName = new java.util.HashMap<String, PublicProfile>();
        res.items().forEach(i -> byName.put(i.displayName(), i));
        assertTrue(byName.containsKey("Şirin Yıldız"), "Turkce harf + buyuk/kucuk harf duyarsiz kismi eslesme");
        assertTrue(byName.containsKey("Ayşe Yıldızhan"));
        assertFalse(byName.containsKey("Çağla Yıldırım"));
        assertEquals(Boolean.TRUE, byName.get("Şirin Yıldız").followedByMe());
        assertEquals(Boolean.FALSE, byName.get("Şirin Yıldız").followsMe());
        assertEquals(1L, byName.get("Şirin Yıldız").followerCount());
        assertEquals(Boolean.FALSE, byName.get(stranger.getDisplayName()).followedByMe());
    }
}
