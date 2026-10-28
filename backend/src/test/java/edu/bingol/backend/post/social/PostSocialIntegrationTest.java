package edu.bingol.backend.post.social;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.follow.FollowService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Gonderi sosyal ozellikleri: takip, akis kapsamlari, KVKK (H2 uyumlu yollar). */
@SpringBootTest
class PostSocialIntegrationTest {

    @Autowired PostService posts;
    @Autowired edu.bingol.backend.post.PostRepository postRepo;
    @Autowired edu.bingol.backend.post.media.PostMediaRepository mediaRepo;
    @Autowired FollowService follow;
    @Autowired SocialAccountPurger purger;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired JdbcTemplate jdbc;
    @Autowired List<DataExporter> exporters;

    private User user(String dept) {
        User u = new User();
        u.setEmail("s" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kullanici " + UUID.randomUUID().toString().substring(0, 4));
        u.setEmailVerified(true);
        u.setDepartment(dept);
        return users.saveAndFlush(u);
    }

    private PostView post(User u, String text) {
        return posts.get(u.getId(), PostFixtures.withPhoto(postRepo, mediaRepo, u.getId(), text).getId());
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    private int notifCount(Long userId, String type) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ? AND type = ?", Integer.class,
                userId, type);
        return n == null ? 0 : n;
    }

    // ------------------------------------------------------------------ takip

    @Test
    void followRulesCountersAndIdempotency() {
        User a = user(null);
        User b = user(null);
        assertEquals("FOLLOW_SELF", code(() -> follow.follow(a.getId(), a.getId())));
        assertEquals("USER_NOT_FOUND", code(() -> follow.follow(a.getId(), -5L)));

        assertEquals(1, follow.follow(a.getId(), b.getId()).followerCount());
        assertEquals(1, follow.follow(a.getId(), b.getId()).followerCount(), "ikinci cagri sayaci artirmaz");
        FollowService.Stats sb = follow.stats(a.getId(), b.getId());
        assertEquals(1, sb.followerCount());
        assertTrue(sb.followedByMe());
        assertEquals(1, follow.stats(b.getId(), a.getId()).followingCount());

        assertEquals(0, follow.unfollow(a.getId(), b.getId()).followerCount());
        assertEquals(0, follow.unfollow(a.getId(), b.getId()).followerCount(), "tekrar birakma sayaci eksiye dusurmez");
        assertEquals(0, follow.stats(a.getId(), a.getId()).followingCount());
    }

    @Test
    void followsMeFlagsInStatsAndLists() {
        User a = user(null);
        User b = user(null);
        User c = user(null);
        follow.follow(b.getId(), a.getId()); // b -> a
        follow.follow(a.getId(), c.getId()); // a -> c
        follow.follow(c.getId(), a.getId()); // c -> a (karsilikli)
        FollowService.Stats s = follow.stats(a.getId(), b.getId());
        assertTrue(s.followsMe());
        assertFalse(s.followedByMe());
        assertFalse(follow.stats(a.getId(), a.getId()).followsMe(), "kendi profilinde false");
        List<FollowService.UserItem> items = follow.followers(a.getId(), a.getId(), null, 20).items();
        assertEquals(2, items.size());
        for (FollowService.UserItem it : items) {
            assertTrue(it.followsMe());
            assertEquals(it.id().equals(c.getId()), it.followedByMe());
        }
        // baska bakan: b, a'nin takipcilerini goruntuler; kendi satiri isaretsiz
        for (FollowService.UserItem it : follow.followers(b.getId(), a.getId(), null, 20).items()) {
            if (it.id().equals(b.getId())) {
                assertFalse(it.followedByMe());
                assertFalse(it.followsMe());
            }
        }
    }

    @Test
    void blockedPairsCannotFollowAndListsHideBlocked() {
        User a = user(null);
        User b = user(null);
        User c = user(null);
        blocks.saveAndFlush(new UserBlock(b.getId(), a.getId()));
        assertEquals("USER_NOT_FOUND", code(() -> follow.follow(a.getId(), b.getId())));
        assertEquals("USER_NOT_FOUND", code(() -> follow.follow(b.getId(), a.getId())));

        follow.follow(a.getId(), c.getId());
        follow.follow(b.getId(), c.getId());
        List<Long> ids = follow.followers(a.getId(), c.getId(), null, 20).items().stream()
                .map(FollowService.UserItem::id).toList();
        assertTrue(ids.contains(a.getId()));
        assertFalse(ids.contains(b.getId()), "engelli takipci listede gorunmez");
        assertTrue(follow.followers(a.getId(), b.getId(), null, 20).items().isEmpty(), "engelli kullanicinin listesi bos");
    }

    @Test
    void followListsPageWithCursor() {
        User target = user(null);
        for (int i = 0; i < 5; i++) {
            follow.follow(user(null).getId(), target.getId());
        }
        FollowService.UserPage p1 = follow.followers(target.getId(), target.getId(), null, 2);
        assertEquals(2, p1.items().size());
        assertNotNull(p1.nextCursor());
        FollowService.UserPage p2 = follow.followers(target.getId(), target.getId(), p1.nextCursor(), 2);
        assertEquals(2, p2.items().size());
        assertFalse(p2.items().stream().anyMatch(i -> p1.items().stream().anyMatch(j -> j.id().equals(i.id()))));
        FollowService.UserPage p3 = follow.followers(target.getId(), target.getId(), p2.nextCursor(), 2);
        assertEquals(1, p3.items().size());
        assertNull(p3.nextCursor());
    }

    @Test
    void followSendsNotificationOnce() {
        User a = user(null);
        User b = user(null);
        follow.follow(a.getId(), b.getId());
        follow.follow(a.getId(), b.getId());
        assertEquals(1, notifCount(b.getId(), "USER_FOLLOW"));
        assertEquals(0, notifCount(a.getId(), "USER_FOLLOW"));
    }

    @Test
    void suggestionsPreferSameDepartmentAndSkipFollowedAndBlocked() {
        String dept = "Bölüm-" + UUID.randomUUID().toString().substring(0, 6);
        User me = user(dept);
        User same1 = user(dept);
        User same2 = user(dept);
        User same3 = user(dept);
        User other = user("Baska-" + UUID.randomUUID().toString().substring(0, 6));
        follow.follow(me.getId(), same1.getId());
        blocks.saveAndFlush(new UserBlock(me.getId(), same2.getId()));
        List<Long> ids = follow.suggestions(me.getId(), 10).stream().map(FollowService.Suggestion::id).toList();
        assertTrue(ids.contains(same3.getId()));
        assertFalse(ids.contains(same1.getId()), "zaten takip edilen onerilmez");
        assertFalse(ids.contains(same2.getId()), "engelli onerilmez");
        assertFalse(ids.contains(other.getId()));
        assertFalse(ids.contains(me.getId()));
    }

    // ------------------------------------------------------------------ akis kapsamlari

    @Test
    void feedScopesFollowingAndDepartment() {
        String dept = "Akis-" + UUID.randomUUID().toString().substring(0, 6);
        User me = user(dept);
        User mate = user(dept);
        User followed = user(null);
        User stranger = user(null);
        PostView mine = post(me, "benim");
        PostView pMate = post(mate, "bolum arkadasi");
        PostView pFollowed = post(followed, "takip edilen");
        PostView pStranger = post(stranger, "yabanci");
        follow.follow(me.getId(), followed.getId());

        List<Long> following = posts.feed(me.getId(), "following", null, 20).items().stream().map(PostView::id).toList();
        assertTrue(following.containsAll(List.of(mine.id(), pFollowed.id())));
        assertFalse(following.contains(pStranger.id()));
        assertFalse(following.contains(pMate.id()));

        List<Long> dep = posts.feed(me.getId(), "department", null, 20).items().stream().map(PostView::id).toList();
        assertTrue(dep.containsAll(List.of(mine.id(), pMate.id())));
        assertFalse(dep.contains(pFollowed.id()));

        User noDept = user(null);
        FeedPage empty = posts.feed(noDept.getId(), "department", null, 20);
        assertTrue(empty.items().isEmpty());
        assertEquals("NO_DEPARTMENT", empty.hint());

        assertEquals("FEED_SCOPE_INVALID", code(() -> posts.feed(me.getId(), "bogus", null, 10)));
        // mevcut kapsamlar bozulmadi
        assertFalse(posts.feed(me.getId(), "latest", null, 5).items().isEmpty());
    }

    @Test
    void followingFeedPagesWithCursor() {
        User me = user(null);
        User f = user(null);
        follow.follow(me.getId(), f.getId());
        for (int i = 0; i < 5; i++) {
            post(f, "g" + i);
        }
        FeedPage p1 = posts.feed(me.getId(), "following", null, 3);
        assertEquals(3, p1.items().size());
        FeedPage p2 = posts.feed(me.getId(), "following", p1.nextCursor(), 3);
        assertEquals(2, p2.items().size());
        assertNull(p2.nextCursor());
    }

    // ------------------------------------------------------------------ KVKK

    @Test
    void accountPurgeRemovesSocialData() {
        User a = user(null);
        User b = user(null);
        follow.follow(a.getId(), b.getId());
        follow.follow(b.getId(), a.getId());

        purger.purge(a.getId());

        assertEquals(0, count("SELECT COUNT(*) FROM user_follow WHERE follower_id = ? OR followee_id = ?", a.getId(), a.getId()));
        assertEquals(0, follow.stats(b.getId(), b.getId()).followerCount(), "karsi tarafin sayaci duser");
        assertEquals(0, follow.stats(b.getId(), b.getId()).followingCount());
    }

    @Test
    void exportersAreRegistered() {
        List<String> sections = exporters.stream().map(DataExporter::section).toList();
        assertTrue(sections.containsAll(List.of("follows")));
        User a = user(null);
        User b = user(null);
        follow.follow(a.getId(), b.getId());
        Object f = exporters.stream().filter(e -> e.section().equals("follows")).findFirst().orElseThrow().export(a.getId());
        assertTrue(f.toString().contains(String.valueOf(b.getId())));
        assertTrue(sections.stream().noneMatch(x -> x.equals("savedPosts") || x.equals("stories")));
    }

    private long count(String sql, Object... args) {
        Long n = jdbc.queryForObject(sql, Long.class, args);
        return n == null ? 0 : n;
    }
}
