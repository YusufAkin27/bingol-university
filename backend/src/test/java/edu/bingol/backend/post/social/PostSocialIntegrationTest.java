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
        return posts.create(u.getId(), new CreatePostRequest(text, null));
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

    // ------------------------------------------------------------------ kaydet

    @Test
    void savePostsFlagListOrderAndHiding() {
        User a = user(null);
        User b = user(null);
        PostView p1 = post(b, "bir");
        PostView p2 = post(b, "iki");
        saves.save(a.getId(), p1.id());
        saves.save(a.getId(), p1.id());
        saves.save(a.getId(), p2.id());
        assertTrue(posts.get(a.getId(), p1.id()).savedByMe());
        assertFalse(posts.get(b.getId(), p1.id()).savedByMe(), "kaydeden gizli: baskasi goremez");

        FeedPage list = saves.list(a.getId(), null, 10);
        assertEquals(List.of(p2.id(), p1.id()), list.items().stream().map(PostView::id).toList());
        assertTrue(list.items().stream().allMatch(PostView::savedByMe));
        assertTrue(saves.list(b.getId(), null, 10).items().isEmpty(), "yalniz kendi listem");

        saves.unsave(a.getId(), p1.id());
        saves.unsave(a.getId(), p1.id());
        assertEquals(1, saves.list(a.getId(), null, 10).items().size());

        jdbc.update("UPDATE post SET hidden_at = CURRENT_TIMESTAMP WHERE id = ?", p2.id());
        assertTrue(saves.list(a.getId(), null, 10).items().isEmpty(), "gizlenen gonderi listeden duser");
        assertEquals("POST_NOT_FOUND", code(() -> saves.save(a.getId(), p2.id())));
    }

    @Test
    void savedListPagesWithCursor() {
        User a = user(null);
        User b = user(null);
        for (int i = 0; i < 4; i++) {
            saves.save(a.getId(), post(b, "k" + i).id());
        }
        FeedPage p1 = saves.list(a.getId(), null, 3);
        assertEquals(3, p1.items().size());
        FeedPage p2 = saves.list(a.getId(), p1.nextCursor(), 3);
        assertEquals(1, p2.items().size());
        assertNull(p2.nextCursor());
    }

    // ------------------------------------------------------------------ #etiket

    @Test
    void hashtagsAreIndexedUpdatedAndQueried() {
        tags.clearCache();
        User a = user(null);
        String t1 = "bahar" + UUID.randomUUID().toString().substring(0, 6).replaceAll("[^a-z]", "x");
        PostView p = post(a, "Merhaba #" + t1 + " #Gündüz");
        assertTrue(p.hashtags().contains(t1));
        assertTrue(p.hashtags().contains("gündüz"));

        FeedPage byTag = tags.posts(a.getId(), t1, null, 10);
        assertEquals(List.of(p.id()), byTag.items().stream().map(PostView::id).toList());
        // aksansiz arama ayni etikete gider
        assertEquals(1, tags.posts(a.getId(), "GUNDUZ", null, 100).items().stream().filter(x -> x.id().equals(p.id())).count());

        assertTrue(tags.suggest(t1.substring(0, 6)).stream().anyMatch(s -> s.tag().equals(t1)));
        assertTrue(tags.trending(20).stream().anyMatch(s -> s.tag().equals(t1)));

        // duzenleme etiketi kaldirir
        PostView edited = posts.update(a.getId(), p.id(), "etiketsiz");
        assertTrue(edited.hashtags().isEmpty());
        assertTrue(tags.posts(a.getId(), t1, null, 10).items().isEmpty());
    }

    @Test
    void hashtagFeedHidesDeletedHiddenAndBlocked() {
        tags.clearCache();
        User a = user(null);
        User b = user(null);
        User viewer = user(null);
        String tag = "etk" + UUID.randomUUID().toString().substring(0, 6).replaceAll("[^a-z]", "y");
        PostView ok = post(a, "#" + tag + " bir");
        PostView gone = post(a, "#" + tag + " iki");
        PostView hidden = post(a, "#" + tag + " uc");
        PostView blockedAuthor = post(b, "#" + tag + " dort");
        posts.delete(a.getId(), gone.id(), false);
        jdbc.update("UPDATE post SET hidden_at = CURRENT_TIMESTAMP WHERE id = ?", hidden.id());
        blocks.saveAndFlush(new UserBlock(viewer.getId(), b.getId()));

        List<Long> ids = tags.posts(viewer.getId(), tag, null, 20).items().stream().map(PostView::id).toList();
        assertEquals(List.of(ok.id()), ids);
        assertFalse(ids.contains(blockedAuthor.id()));
    }

    @Test
    void invalidTagIsRejectedAndUnknownTagIsEmpty() {
        User a = user(null);
        assertEquals("HASHTAG_INVALID", code(() -> tags.posts(a.getId(), "a", null, 10)));
        assertTrue(tags.posts(a.getId(), "yokboyleetiket", null, 10).items().isEmpty());
        assertTrue(tags.suggest("").isEmpty());
    }

    // ------------------------------------------------------------------ @etiket

    @Test
    void mentionsAreValidatedStoredAndNotifiedOnce() {
        User a = user(null);
        User b = user(null);
        User blockedByA = user(null);
        blocks.saveAndFlush(new UserBlock(a.getId(), blockedByA.getId()));
        String text = "Selam @[B](uid:" + b.getId() + ") @[Engelli](uid:" + blockedByA.getId() + ") @[Ben](uid:"
                + a.getId() + ") @[Yok](uid:999999999)";
        PostView p = post(a, text);
        assertEquals(text, p.text(), "metin bicimi korunur");
        List<Long> ids = p.mentions().stream().map(m -> m.id()).sorted().toList();
        assertEquals(List.of(Math.min(a.getId(), b.getId()), Math.max(a.getId(), b.getId())), ids);
        assertEquals(1, notifCount(b.getId(), "POST_MENTION"));
        assertEquals(0, notifCount(a.getId(), "POST_MENTION"), "kendi etiketi icin bildirim yok");
        assertEquals(0, notifCount(blockedByA.getId(), "POST_MENTION"));

        // duzenleme: zaten etiketliye tekrar bildirim yok; etiket kaldirilirsa liste temizlenir
        posts.update(a.getId(), p.id(), text + " ek");
        assertEquals(1, notifCount(b.getId(), "POST_MENTION"));
        PostView cleared = posts.update(a.getId(), p.id(), "etiketsiz");
        assertTrue(cleared.mentions().isEmpty());
    }

    @Test
    void tooManyMentionsRejected() {
        User a = user(null);
        StringBuilder b = new StringBuilder();
        for (int i = 1; i <= 11; i++) {
            b.append("@[K](uid:").append(i).append(") ");
        }
        assertEquals("MENTION_TOO_MANY", code(() -> post(a, b.toString())));
    }

    @Test
    void commentMentionsAreReturnedAndNotified() {
        User author = user(null);
        User commenter = user(null);
        User target = user(null);
        PostView p = post(author, "gonderi");
        CommentView c = comments.create(commenter.getId(), p.id(), "Bak @[T](uid:" + target.getId() + ")", null);
        assertEquals(1, c.mentions().size());
        assertEquals(target.getId(), c.mentions().get(0).id());
        assertEquals(1, notifCount(target.getId(), "POST_MENTION"));
    }

    @Test
    void mentionSuggestPrioritisesFollowedAndFiltersBlocked() {
        String dept = "Sg-" + UUID.randomUUID().toString().substring(0, 6);
        User me = user(dept);
        User followed = user(null);
        User mate = user(dept);
        User blockedUser = user(dept);
        follow.follow(me.getId(), followed.getId());
        blocks.saveAndFlush(new UserBlock(me.getId(), blockedUser.getId()));
        List<Long> ids = suggest.suggest(me.getId(), "", null, 8).stream().map(MentionSuggestService.Suggestion::id).toList();
        assertTrue(ids.indexOf(followed.getId()) >= 0 && ids.indexOf(followed.getId()) < ids.indexOf(mate.getId()));
        assertFalse(ids.contains(blockedUser.getId()));
        assertFalse(ids.contains(me.getId()));
        // adla arama (buyuk/kucuk harf duyarsiz)
        List<MentionSuggestService.Suggestion> byName = suggest.suggest(me.getId(),
                followed.getDisplayName().toUpperCase(java.util.Locale.ROOT), null, 8);
        assertTrue(byName.stream().anyMatch(s -> s.id().equals(followed.getId())));
    }

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
