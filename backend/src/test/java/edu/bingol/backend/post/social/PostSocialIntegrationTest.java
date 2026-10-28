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
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.PostCommentService;
import edu.bingol.backend.post.follow.FollowService;
import edu.bingol.backend.post.story.StoryCleanupJob;
import edu.bingol.backend.post.story.StoryDtos.CreateRequest;
import edu.bingol.backend.post.story.StoryDtos.StoryView;
import edu.bingol.backend.post.story.StoryDtos.TrayItem;
import edu.bingol.backend.post.story.StoryService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Gonderi sosyal ozellikleri: takip, kaydet, #etiket, @etiket, akis kapsamlari, hikayeler, KVKK (H2 uyumlu yollar). */
@SpringBootTest
class PostSocialIntegrationTest {

    @Autowired PostService posts;
    @Autowired edu.bingol.backend.post.PostRepository postRepo;
    @Autowired edu.bingol.backend.post.media.PostMediaRepository mediaRepo;
    @Autowired PostCommentService comments;
    @Autowired FollowService follow;
    @Autowired PostSaveService saves;
    @Autowired HashtagService tags;
    @Autowired StoryService stories;
    @Autowired StoryCleanupJob cleanup;
    @Autowired SocialAccountPurger purger;
    @Autowired MentionSuggestService suggest;
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

    // Kaydet / #etiket / @bahsetme testleri sade Kesfet sozlesmesiyle kaldirildi (uclar 410, olay yayinlanmaz).

    // ------------------------------------------------------------------ hikayeler

    @Test
    void textStoryValidation() {
        User a = user(null);
        assertEquals("STORY_EMPTY", code(() -> stories.create(a.getId(), new CreateRequest(null, null, "cap", null))));
        assertEquals("STORY_BACKGROUND_INVALID",
                code(() -> stories.create(a.getId(), new CreateRequest(null, "merhaba", null, "kirmizi"))));
        assertEquals("STORY_TOO_LONG",
                code(() -> stories.create(a.getId(), new CreateRequest(null, "x".repeat(201), null, null))));
        assertEquals("POST_MEDIA_INVALID", code(() -> stories.create(a.getId(), new CreateRequest(987654L, null, null, null))));
        StoryView s = stories.create(a.getId(), new CreateRequest(null, "merhaba", "alt", "#ff0000"));
        assertEquals("TEXT", s.kind());
        assertEquals("#FF0000", s.background());
        assertTrue(s.mine());
        assertEquals(0, s.viewCount());
        assertTrue(s.expiresAt().isAfter(Instant.now().plus(23, ChronoUnit.HOURS)));
    }

    @Test
    void trayOrderViewsAndViewersAccess() {
        User viewer = user(null);
        User seenAuthor = user(null);
        User unseenAuthor = user(null);
        User notFollowed = user(null);
        follow.follow(viewer.getId(), seenAuthor.getId());
        follow.follow(viewer.getId(), unseenAuthor.getId());
        StoryView mine = stories.create(viewer.getId(), new CreateRequest(null, "benim", null, null));
        StoryView s1 = stories.create(seenAuthor.getId(), new CreateRequest(null, "bir", null, null));
        stories.create(unseenAuthor.getId(), new CreateRequest(null, "iki", null, null));
        stories.create(notFollowed.getId(), new CreateRequest(null, "uc", null, null));

        stories.markViewed(viewer.getId(), s1.id());
        stories.markViewed(viewer.getId(), s1.id());
        List<TrayItem> tray = stories.tray(viewer.getId());
        assertEquals(3, tray.size(), "kendim + takip ettiklerim; takip edilmeyen yok");
        assertTrue(tray.get(0).mine());
        assertEquals(unseenAuthor.getId(), tray.get(1).user().id());
        assertTrue(tray.get(1).hasUnseen());
        assertEquals(seenAuthor.getId(), tray.get(2).user().id());
        assertFalse(tray.get(2).hasUnseen());

        // sayac idempotent; sahibi sayilmaz
        stories.markViewed(seenAuthor.getId(), s1.id());
        assertEquals(1, stories.ofUser(seenAuthor.getId(), seenAuthor.getId()).get(0).viewCount());
        assertNull(stories.ofUser(viewer.getId(), seenAuthor.getId()).get(0).viewCount(), "sayac yalniz sahibe");
        assertTrue(stories.ofUser(viewer.getId(), seenAuthor.getId()).get(0).viewedByMe());

        assertEquals(1, stories.viewers(seenAuthor.getId(), s1.id(), null, 10).items().size());
        assertEquals("STORY_FORBIDDEN", code(() -> stories.viewers(viewer.getId(), s1.id(), null, 10)));
        assertEquals(1, stories.ofUser(viewer.getId(), viewer.getId()).size());
        assertEquals(mine.id(), stories.ofUser(viewer.getId(), viewer.getId()).get(0).id());
    }

    @Test
    void blockedAndExpiredAndDeletedStoriesAreInvisible() {
        User a = user(null);
        User b = user(null);
        StoryView s = stories.create(a.getId(), new CreateRequest(null, "gizlenecek", null, null));
        assertEquals(1, stories.ofUser(b.getId(), a.getId()).size());

        blocks.saveAndFlush(new UserBlock(b.getId(), a.getId()));
        assertTrue(stories.ofUser(b.getId(), a.getId()).isEmpty());
        assertEquals("STORY_NOT_FOUND", code(() -> stories.markViewed(b.getId(), s.id())));
        blocks.deleteAll(blocks.findAll().stream().filter(x -> x.getBlockerId().equals(b.getId())).toList());

        // sure dolumu
        jdbc.update("UPDATE story SET expires_at = ? WHERE id = ?",
                java.sql.Timestamp.from(Instant.now().minusSeconds(60)), s.id());
        assertTrue(stories.ofUser(b.getId(), a.getId()).isEmpty());
        assertEquals("STORY_NOT_FOUND", code(() -> stories.markViewed(b.getId(), s.id())));

        // sahibi silme: baskasi silemez
        StoryView s2 = stories.create(a.getId(), new CreateRequest(null, "silinecek", null, null));
        assertEquals("STORY_FORBIDDEN", code(() -> stories.delete(b.getId(), s2.id(), false)));
        stories.delete(a.getId(), s2.id(), false);
        assertTrue(stories.ofUser(a.getId(), a.getId()).isEmpty());
        assertEquals("STORY_NOT_FOUND", code(() -> stories.delete(a.getId(), s2.id(), false)));
    }

    @Test
    void cleanupRemovesExpiredAfterRetention() {
        User a = user(null);
        StoryView expiredLong = stories.create(a.getId(), new CreateRequest(null, "eski", null, null));
        StoryView expiredRecent = stories.create(a.getId(), new CreateRequest(null, "yeni bitti", null, null));
        StoryView live = stories.create(a.getId(), new CreateRequest(null, "canli", null, null));
        Instant now = Instant.now();
        jdbc.update("UPDATE story SET expires_at = ? WHERE id = ?",
                java.sql.Timestamp.from(now.minus(30, ChronoUnit.HOURS)), expiredLong.id());
        jdbc.update("UPDATE story SET expires_at = ? WHERE id = ?",
                java.sql.Timestamp.from(now.minus(2, ChronoUnit.HOURS)), expiredRecent.id());
        assertTrue(cleanup.run(now) >= 1);
        assertEquals(0, count("SELECT COUNT(*) FROM story WHERE id = ?", expiredLong.id()));
        assertEquals(1, count("SELECT COUNT(*) FROM story WHERE id = ?", expiredRecent.id()), "24 saat dolmadi");
        assertEquals(1, count("SELECT COUNT(*) FROM story WHERE id = ?", live.id()));
    }

    // ------------------------------------------------------------------ KVKK

    @Test
    void accountPurgeRemovesSocialData() {
        User a = user(null);
        User b = user(null);
        PostView p = post(b, "kaydedilecek");
        saves.save(a.getId(), p.id());
        follow.follow(a.getId(), b.getId());
        follow.follow(b.getId(), a.getId());
        stories.create(a.getId(), new CreateRequest(null, "benim", null, null));

        purger.purge(a.getId());

        assertEquals(0, count("SELECT COUNT(*) FROM post_save WHERE user_id = ?", a.getId()));
        assertEquals(0, count("SELECT COUNT(*) FROM user_follow WHERE follower_id = ? OR followee_id = ?", a.getId(), a.getId()));
        assertEquals(0, count("SELECT COUNT(*) FROM story WHERE author_id = ?", a.getId()));
        assertEquals(0, follow.stats(b.getId(), b.getId()).followerCount(), "karsi tarafin sayaci duser");
        assertEquals(0, follow.stats(b.getId(), b.getId()).followingCount());
    }

    @Test
    void exportersAreRegistered() {
        List<String> sections = exporters.stream().map(DataExporter::section).toList();
        assertTrue(sections.containsAll(List.of("savedPosts", "follows", "stories")));
        User a = user(null);
        User b = user(null);
        follow.follow(a.getId(), b.getId());
        stories.create(a.getId(), new CreateRequest(null, "x", null, null));
        Object f = exporters.stream().filter(e -> e.section().equals("follows")).findFirst().orElseThrow().export(a.getId());
        assertTrue(f.toString().contains(String.valueOf(b.getId())));
        Object s = exporters.stream().filter(e -> e.section().equals("stories")).findFirst().orElseThrow().export(a.getId());
        assertTrue(s.toString().contains("TEXT"));
    }

    private long count(String sql, Object... args) {
        Long n = jdbc.queryForObject(sql, Long.class, args);
        return n == null ? 0 : n;
    }
}
