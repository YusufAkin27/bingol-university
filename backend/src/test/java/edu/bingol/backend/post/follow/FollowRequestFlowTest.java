package edu.bingol.backend.post.follow;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.dbmaint.DbMaintenanceJob;
import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.messaging.MessageRequestPolicy;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostFixtures;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.like.PostLikeService;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.post.media.PostMediaService;
import edu.bingol.backend.profile.AccountDataPurger;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import edu.bingol.backend.profile.privacy.PrivacyService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** FOLLOWREQ: gizli hesap + takip istegi (H2, tum katmanlar). */
@SpringBootTest
class FollowRequestFlowTest {

    @MockitoBean RateLimiter limiter;

    @Autowired FollowService follow;
    @Autowired FollowRequestService requests;
    @Autowired PrivacyService privacy;
    @Autowired ProfileService profiles;
    @Autowired PostService posts;
    @Autowired PostRepository postRepo;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired PostMediaService mediaService;
    @Autowired PostLikeService likes;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired JdbcTemplate jdbc;
    @Autowired MessageRequestPolicy messagePolicy;
    @Autowired DbMaintenanceJob dbMaint;
    @Autowired List<DataExporter> exporters;

    @BeforeEach
    void resetLimiter() {
        reset(limiter);
    }

    // ---------------------------------------------------------------- yardimcilar

    private User user(String lang) {
        User u = new User();
        u.setEmail("f" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi " + UUID.randomUUID().toString().substring(0, 4));
        u.setEmailVerified(true);
        u.setDepartment("Bilgisayar");
        u.setLanguage(lang);
        return users.saveAndFlush(u);
    }

    private User user() {
        return user("tr");
    }

    private void setPrivate(User u, boolean v) {
        privacy.update(u.getId(), new UpdatePrivacyRequest(null, null, null, null, null, null, v));
    }

    private User privateUser() {
        User u = user();
        setPrivate(u, true);
        return u;
    }

    private int count(String sql, Object... args) {
        Integer n = jdbc.queryForObject(sql, Integer.class, args);
        return n == null ? 0 : n;
    }

    private int requestRows(Long requester, Long target) {
        return count("SELECT COUNT(*) FROM follow_request WHERE requester_id = ? AND target_id = ?", requester, target);
    }

    private int followRows(Long follower, Long followee) {
        return count("SELECT COUNT(*) FROM user_follow WHERE follower_id = ? AND followee_id = ?", follower, followee);
    }

    private List<Map<String, Object>> notifs(Long userId, String type) {
        return jdbc.queryForList("SELECT title, body, subtype, data, collapse_key FROM notification WHERE user_id = ? "
                + "AND type = ?", userId, type);
    }

    private Post photoPost(User author, String text) {
        return PostFixtures.withPhoto(postRepo, mediaRepo, author.getId(), text);
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    private boolean inAnyFeed(Long viewer, Long postId) {
        for (String scope : List.of("latest", "popular", "top", "following", "department")) {
            FeedPage page = posts.feed(viewer, scope, null, 20);
            if (page.items().stream().anyMatch(p -> p.id().equals(postId))) {
                return true;
            }
        }
        return false;
    }

    // ---------------------------------------------------------------- takip / istek

    @Test
    void publicAccountIsFollowedImmediatelyAndNeverGetsRequests() {
        User a = user();
        User b = user();
        FollowService.FollowResult r = follow.follow(a.getId(), b.getId());
        assertTrue(r.following());
        assertEquals("FOLLOWING", r.followState());
        assertEquals(1, r.followerCount());
        assertEquals(1, followRows(a.getId(), b.getId()));
        assertEquals(0, requestRows(a.getId(), b.getId()));
        assertEquals(0, count("SELECT COUNT(*) FROM follow_request WHERE target_id = ?", b.getId()));
        assertEquals(1, notifs(b.getId(), "USER_FOLLOW").size(), "acik hesapta yeni takipci bildirimi aninda");
    }

    @Test
    void privateAccountCreatesIdempotentRequestInsteadOfFollow() {
        User a = user();
        User t = privateUser();
        FollowService.FollowResult r = follow.follow(a.getId(), t.getId());
        assertFalse(r.following());
        assertEquals("REQUESTED", r.followState());
        assertEquals(0, r.followerCount(), "gizli hesapta sayac sizdirilmaz");
        assertEquals(0, followRows(a.getId(), t.getId()), "gercek takip YOK");
        assertEquals(1, requestRows(a.getId(), t.getId()));

        // tekrar cagri: idempotent (ikinci satir yok, hiz limiti ikinci kez harcanmaz)
        assertEquals("REQUESTED", follow.follow(a.getId(), t.getId()).followState());
        assertEquals(1, requestRows(a.getId(), t.getId()));
        verify(limiter, times(1)).check("followreq:" + a.getId() + ":" + t.getId(), 3, Duration.ofDays(1));

        // hedefe istek bildirimi gitti, "yeni takipci" bildirimi gitmedi
        assertEquals(1, notifs(t.getId(), "FOLLOW_REQUEST").size());
        assertEquals(0, notifs(t.getId(), "USER_FOLLOW").size());
        assertEquals(0, follow.stats(a.getId(), t.getId()).followerCount());
    }

    @Test
    void withdrawingTheRequestAndUnfollowingReturnNone() {
        User a = user();
        User t = privateUser();
        follow.follow(a.getId(), t.getId());
        FollowService.FollowResult w = follow.unfollow(a.getId(), t.getId());
        assertEquals("NONE", w.followState());
        assertFalse(w.following());
        assertEquals(0, requestRows(a.getId(), t.getId()));
        assertEquals("NONE", follow.unfollow(a.getId(), t.getId()).followState(), "tekrar: no-op");

        // kabul edilmis takipci cikinca tekrar istek gerekir
        follow.follow(a.getId(), t.getId());
        requests.accept(t.getId(), a.getId());
        assertEquals(1, followRows(a.getId(), t.getId()));
        assertEquals("NONE", follow.unfollow(a.getId(), t.getId()).followState());
        assertEquals(0, followRows(a.getId(), t.getId()));
        assertEquals("REQUESTED", follow.follow(a.getId(), t.getId()).followState(), "yeniden istek zorunlu");
    }

    @Test
    void acceptCreatesRealFollowCountersAndNotifiesRequester() {
        User a = user("en");
        User t = privateUser();
        follow.follow(a.getId(), t.getId());

        int left = requests.accept(t.getId(), a.getId());
        assertEquals(0, left);
        assertEquals(1, followRows(a.getId(), t.getId()));
        assertEquals(0, requestRows(a.getId(), t.getId()));
        FollowService.Stats s = follow.stats(a.getId(), t.getId());
        assertEquals(1, s.followerCount());
        assertTrue(s.followedByMe());
        assertEquals(1, follow.stats(t.getId(), a.getId()).followingCount());

        List<Map<String, Object>> n = notifs(a.getId(), "FOLLOW_ACCEPTED");
        assertEquals(1, n.size());
        assertEquals("FOLLOW_ACCEPTED", n.get(0).get("subtype"));
        assertTrue(String.valueOf(n.get(0).get("data")).contains("USER"), "push hedefi USER (kabul eden)");
        assertTrue(String.valueOf(n.get(0).get("data")).contains(String.valueOf(t.getId())));
        assertEquals(0, notifs(t.getId(), "USER_FOLLOW").size(), "kabul eden kendine 'yeni takipci' bildirimi almaz");

        // idempotent: ikinci kabul ek takip/bildirim uretmez
        requests.accept(t.getId(), a.getId());
        assertEquals(1, follow.stats(a.getId(), t.getId()).followerCount());
        assertEquals(1, notifs(a.getId(), "FOLLOW_ACCEPTED").size());
    }

    @Test
    void declineIsSilentIdempotentAndAllowsALaterRequest() {
        User a = user();
        User t = privateUser();
        follow.follow(a.getId(), t.getId());
        assertEquals(0, requests.decline(t.getId(), a.getId()));
        assertEquals(0, requests.decline(t.getId(), a.getId()), "idempotent");
        assertEquals(0, requestRows(a.getId(), t.getId()));
        assertEquals(0, followRows(a.getId(), t.getId()));
        assertEquals(0, notifs(a.getId(), "FOLLOW_ACCEPTED").size(), "red sessiz: istek sahibine bildirim yok");
        assertEquals("REQUESTED", follow.follow(a.getId(), t.getId()).followState(), "reddedilen sonra tekrar isteyebilir");
        assertEquals(1, requestRows(a.getId(), t.getId()));
    }

    @Test
    void sameTargetRateLimitIsThreePerDayAndBlocksTheInsert() {
        User a = user();
        User t = privateUser();
        String key = "followreq:" + a.getId() + ":" + t.getId();
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "cok fazla")).when(limiter)
                .check(eq(key), eq(3), eq(Duration.ofDays(1)));
        assertEquals("RATE_LIMITED", code(() -> follow.follow(a.getId(), t.getId())));
        assertEquals(0, requestRows(a.getId(), t.getId()), "limit asilinca istek olusmaz");
    }

    @Test
    void pendingOutgoingRequestCapIs200() {
        User a = user();
        for (int i = 0; i < FollowRequestService.MAX_PENDING_OUT; i++) {
            jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                    a.getId(), 900_000L + i);
        }
        User t = privateUser();
        ApiException e = assertThrows(ApiException.class, () -> follow.follow(a.getId(), t.getId()));
        assertEquals("FOLLOW_REQUEST_LIMIT", e.code());
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, e.status());
        assertEquals(0, requestRows(a.getId(), t.getId()));
        // limit doluyken zaten bekleyen istege tekrar cagri hata vermez (idempotent)
        jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                a.getId(), t.getId());
        assertEquals("REQUESTED", follow.follow(a.getId(), t.getId()).followState());
        requests.purgeUser(a.getId()); // sahte hedefli satirlari diger testlere birakma
    }

    @Test
    void cannotFollowSelfAndBlockedPairsNeverCreateRequests() {
        User a = user();
        User t = privateUser();
        assertEquals("FOLLOW_SELF", code(() -> follow.follow(t.getId(), t.getId())));

        // hedef beni engelledi: golge engel (hata yok, istek yok)
        blocks.saveAndFlush(new UserBlock(t.getId(), a.getId()));
        FollowService.FollowResult r = follow.follow(a.getId(), t.getId());
        assertEquals(0, r.followerCount());
        assertEquals(0, requestRows(a.getId(), t.getId()));
        assertEquals(0, notifs(t.getId(), "FOLLOW_REQUEST").size());

        // ben engelledim: 404
        User b = user();
        User t2 = privateUser();
        blocks.saveAndFlush(new UserBlock(b.getId(), t2.getId()));
        assertEquals("USER_NOT_FOUND", code(() -> follow.follow(b.getId(), t2.getId())));
        assertEquals(0, requestRows(b.getId(), t2.getId()));
    }

    // ---------------------------------------------------------------- gelen istekler

    @Test
    void incomingListCountAndCursorSkipBlockedAndInactiveRequesters() {
        User t = privateUser();
        List<User> rs = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            User r = user();
            rs.add(r);
            follow.follow(r.getId(), t.getId());
        }
        assertEquals(5, requests.count(t.getId()));
        CursorPage<FollowRequestService.RequestItem> p1 = requests.incoming(t.getId(), null, 2);
        assertEquals(2, p1.items().size());
        assertNotNull(p1.nextCursor());
        assertEquals(rs.get(4).getId(), p1.items().get(0).userId(), "en yeni once");
        assertNotNull(p1.items().get(0).requestedAt());
        CursorPage<FollowRequestService.RequestItem> p2 = requests.incoming(t.getId(), p1.nextCursor(), 10);
        assertEquals(3, p2.items().size());
        assertNull(p2.nextCursor());

        // engelli istek sahibi listede ve sayaca girmez
        blocks.saveAndFlush(new UserBlock(t.getId(), rs.get(0).getId()));
        assertEquals(4, requests.count(t.getId()));
        // pasif hesap da girmez
        User r1 = users.findById(rs.get(1).getId()).orElseThrow();
        r1.setStatus(edu.bingol.backend.user.UserStatus.SUSPENDED);
        users.saveAndFlush(r1);
        assertEquals(3, requests.count(t.getId()));
    }

    @Test
    void acceptWithBlockOrInactiveRequesterJustDropsTheRequest() {
        User t = privateUser();
        User r = user();
        follow.follow(r.getId(), t.getId());
        blocks.saveAndFlush(new UserBlock(r.getId(), t.getId()));
        requests.accept(t.getId(), r.getId());
        assertEquals(0, requestRows(r.getId(), t.getId()));
        assertEquals(0, followRows(r.getId(), t.getId()));
        assertEquals(0, notifs(r.getId(), "FOLLOW_ACCEPTED").size());
    }

    // ---------------------------------------------------------------- gecisler

    @Test
    void privateToPublicAutoAcceptsEveryPendingRequestInChunks() {
        User t = privateUser();
        int n = 2 * FollowRequestService.AUTO_ACCEPT_CHUNK + 5;
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            ids.add(user().getId());
        }
        for (Long id : ids) {
            jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                    id, t.getId());
        }
        assertEquals(n, requests.count(t.getId()));

        setPrivate(t, false); // gizli -> acik

        assertEquals(0, count("SELECT COUNT(*) FROM follow_request WHERE target_id = ?", t.getId()));
        assertEquals(n, count("SELECT COUNT(*) FROM user_follow WHERE followee_id = ?", t.getId()));
        assertEquals(n, follow.followerCount(t.getId()), "takipci sayaci tutarli");
        assertEquals(1, follow.stats(ids.get(0), ids.get(0)).followingCount());
        assertEquals(1, follow.stats(t.getId(), ids.get(n - 1)).followingCount());
        assertEquals(0, notifs(ids.get(0), "FOLLOW_ACCEPTED").size(), "toplu otomatik kabulde bildirim firtinasi yok");
    }

    @Test
    void healJobAcceptsLeftoverRequestsOfPublicTargets() {
        User t = user(); // herkese acik
        User a = user();
        User b = user();
        jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                a.getId(), t.getId());
        jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) VALUES (?, ?, CURRENT_TIMESTAMP)",
                b.getId(), t.getId());
        int healed = 0;
        for (int i = 0; i < 20 && followRows(a.getId(), t.getId()) == 0; i++) { // ortak veritabaninda baska artiklar olabilir
            healed += requests.healPublicTargets();
        }
        assertTrue(healed >= 2);
        assertEquals(1, followRows(a.getId(), t.getId()));
        assertEquals(1, followRows(b.getId(), t.getId()));
        assertEquals(0, count("SELECT COUNT(*) FROM follow_request WHERE target_id = ?", t.getId()));
    }

    @Test
    void publicToPrivateKeepsExistingFollowersAndTheirAccess() {
        User t = user();
        User f = user();
        follow.follow(f.getId(), t.getId());
        Post p = photoPost(t, "kalir");
        setPrivate(t, true);
        assertEquals(1, followRows(f.getId(), t.getId()), "mevcut takipciler kalir");
        assertTrue(inAnyFeed(f.getId(), p.getId()));
        assertEquals(1, posts.byAuthor(f.getId(), t.getId(), null, 10).items().size());
        assertEquals(Boolean.FALSE, posts.byAuthor(f.getId(), t.getId(), null, 10).locked());
    }

    // ---------------------------------------------------------------- gorunurluk

    @Test
    void lockedProfileShellAndEmptyLists() {
        User t = privateUser();
        User stranger = user();
        User requester = user();
        User follower = user();
        follow.follow(requester.getId(), t.getId());
        follow.follow(follower.getId(), t.getId());
        requests.accept(t.getId(), follower.getId());

        PublicProfile asStranger = profiles.publicProfile(stranger.getId(), t.getId());
        assertEquals(Boolean.TRUE, asStranger.isPrivate());
        assertEquals(Boolean.TRUE, asStranger.locked());
        assertEquals("NONE", asStranger.followState());
        assertEquals(t.getDisplayName(), asStranger.displayName(), "profil kabugu gorunur");
        assertNull(asStranger.followerCount(), "kilitliyken sayaclar gizli");
        assertNull(asStranger.followingCount());

        PublicProfile asRequester = profiles.publicProfile(requester.getId(), t.getId());
        assertEquals("REQUESTED", asRequester.followState());
        assertEquals(Boolean.TRUE, asRequester.locked(), "bekleyen istek kilidi acmaz");

        PublicProfile asFollower = profiles.publicProfile(follower.getId(), t.getId());
        assertEquals("FOLLOWING", asFollower.followState());
        assertEquals(Boolean.FALSE, asFollower.locked());
        assertEquals(1L, asFollower.followerCount());

        PublicProfile asSelf = profiles.publicProfile(t.getId(), t.getId());
        assertEquals("SELF", asSelf.followState());
        assertEquals(Boolean.FALSE, asSelf.locked());
        assertEquals(Boolean.TRUE, asSelf.isPrivate());

        // acik hesap: alanlar var ama kilitli degil
        PublicProfile open = profiles.publicProfile(stranger.getId(), requester.getId());
        assertEquals(Boolean.FALSE, open.isPrivate());
        assertEquals(Boolean.FALSE, open.locked());

        // listeler
        FollowService.UserPage lockedList = follow.followers(stranger.getId(), t.getId(), null, 20);
        assertTrue(lockedList.items().isEmpty());
        assertEquals(Boolean.TRUE, lockedList.locked());
        assertTrue(follow.following(requester.getId(), t.getId(), null, 20).items().isEmpty());
        FollowService.UserPage visible = follow.followers(follower.getId(), t.getId(), null, 20);
        assertEquals(1, visible.items().size());
        assertEquals(Boolean.FALSE, visible.locked());
        assertEquals(1, follow.followers(t.getId(), t.getId(), null, 20).items().size());

        // arama: gizli kullanici bulunur (kabuk), kilitli isaretli
        var found = profiles.search(stranger.getId(), t.getDisplayName(), 10, null).items();
        PublicProfile row = found.stream().filter(x -> x.id().equals(t.getId())).findFirst().orElseThrow();
        assertEquals(Boolean.TRUE, row.locked());
        assertEquals("NONE", row.followState());
    }

    @Test
    void privatePostsAreInvisibleToNonFollowersEverywhere() {
        User owner = privateUser();
        User stranger = user();
        User requester = user();
        User follower = user();
        follow.follow(requester.getId(), owner.getId()); // bekleyen istek
        follow.follow(follower.getId(), owner.getId());
        requests.accept(owner.getId(), follower.getId());
        Post p = photoPost(owner, "gizli gonderi");
        Long mediaId = mediaRepo.findByPostIdOrderByPositionAscIdAsc(p.getId()).get(0).getId();
        follow.follow(follower.getId(), stranger.getId()); // follower -> stranger (following akisinda stranger gorunsun diye)

        // yabanci + bekleyen istek sahibi: hicbir akista yok, tek gonderi 404, liste kilitli, begeni 404, medya yok
        for (User v : List.of(stranger, requester)) {
            assertFalse(inAnyFeed(v.getId(), p.getId()), "akis sizdirmamali");
            assertEquals("POST_NOT_FOUND", code(() -> posts.get(v.getId(), p.getId())));
            FeedPage mine = posts.byAuthor(v.getId(), owner.getId(), null, 10);
            assertTrue(mine.items().isEmpty());
            assertEquals(Boolean.TRUE, mine.locked());
            assertEquals("POST_NOT_FOUND", code(() -> likes.like(v.getId(), p.getId())));
            assertEquals("POST_NOT_FOUND", code(() -> likes.listLikers(p.getId(), v.getId(), null, 10)));
            assertTrue(mediaService.accessible(v.getId(), mediaId).isEmpty());
        }
        // kabul edilmis takipci ve sahibi gorur
        for (User v : List.of(follower, owner)) {
            assertEquals(p.getId(), posts.get(v.getId(), p.getId()).id());
            assertTrue(posts.feed(v.getId(), "latest", null, 20).items().stream().anyMatch(x -> x.id().equals(p.getId())));
            assertTrue(posts.feed(v.getId(), "following", null, 20).items().stream().anyMatch(x -> x.id().equals(p.getId())));
            assertEquals(1, posts.byAuthor(v.getId(), owner.getId(), null, 10).items().size());
            assertTrue(mediaService.accessible(v.getId(), mediaId).isPresent());
        }
        assertEquals(1, likes.like(follower.getId(), p.getId()).likeCount());

        // kabul edilince bekleyen istek sahibi de gorur
        requests.accept(owner.getId(), requester.getId());
        assertEquals(p.getId(), posts.get(requester.getId(), p.getId()).id());
        // takipten cikinca tekrar gorunmez
        follow.unfollow(requester.getId(), owner.getId());
        assertEquals("POST_NOT_FOUND", code(() -> posts.get(requester.getId(), p.getId())));
    }

    @Test
    void makingAccountPublicRevealsPostsAgain() {
        User owner = privateUser();
        User stranger = user();
        Post p = photoPost(owner, "acilir");
        assertEquals("POST_NOT_FOUND", code(() -> posts.get(stranger.getId(), p.getId())));
        setPrivate(owner, false);
        assertEquals(p.getId(), posts.get(stranger.getId(), p.getId()).id());
        assertTrue(inAnyFeed(stranger.getId(), p.getId()));
    }

    // ---------------------------------------------------------------- KVKK / temizlik / mesaj istegi

    @Test
    void purgerRemovesRequestsOnBothColumns() {
        User t = privateUser();
        User a = user();
        User t2 = privateUser();
        follow.follow(a.getId(), t.getId());
        follow.follow(t.getId(), t2.getId()); // t istek gonderen de
        assertEquals(2, count("SELECT COUNT(*) FROM follow_request WHERE requester_id = ? OR target_id = ?",
                t.getId(), t.getId()));
        List<String> mine = AccountDataPurger.DELETES.stream().filter(q -> q.contains("follow_request")).toList();
        assertEquals(2, mine.size(), "iki sutun icin de karar kayitli");
        mine.forEach(q -> jdbc.update(q, t.getId()));
        assertEquals(0, count("SELECT COUNT(*) FROM follow_request WHERE requester_id = ? OR target_id = ?",
                t.getId(), t.getId()));
    }

    @Test
    void purgeUserAlsoClearsRequestsForSuspension() {
        User t = privateUser();
        User a = user();
        follow.follow(a.getId(), t.getId());
        requests.purgeUser(a.getId());
        assertEquals(0, requestRows(a.getId(), t.getId()));
    }

    @Test
    void exportContainsMyPendingSentRequests() {
        User t = privateUser();
        User a = user();
        follow.follow(a.getId(), t.getId());
        DataExporter ex = exporters.stream().filter(e -> "followRequests".equals(e.section())).findFirst().orElseThrow();
        @SuppressWarnings("unchecked")
        Map<String, Object> out = (Map<String, Object>) ex.export(a.getId());
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> sent = (List<Map<String, Object>>) out.get("sentPending");
        assertEquals(1, sent.size());
        // hedefin exportunda gelen istek (baskasinin verisi) YOK
        @SuppressWarnings("unchecked")
        Map<String, Object> theirs = (Map<String, Object>) ex.export(t.getId());
        assertTrue(((List<?>) theirs.get("sentPending")).isEmpty());
    }

    @Test
    void nightlyJobDeletesRequestsOlderThan90Days() {
        User t = privateUser();
        User oldR = user();
        User freshR = user();
        jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) VALUES (?, ?, ?)", oldR.getId(),
                t.getId(), Timestamp.from(Instant.now().minus(Duration.ofDays(100))));
        jdbc.update("INSERT INTO follow_request (requester_id, target_id, created_at) VALUES (?, ?, ?)", freshR.getId(),
                t.getId(), Timestamp.from(Instant.now().minus(Duration.ofDays(10))));
        Map<String, Integer> out = dbMaint.runAll();
        assertTrue(out.containsKey("follow_request"));
        assertEquals(0, requestRows(oldR.getId(), t.getId()));
        assertEquals(1, requestRows(freshR.getId(), t.getId()));
    }

    @Test
    void messageRequestContextCountsAcceptedFollowOnlyNotPendingRequest() {
        User t = privateUser(); // gizli hesap sahibi
        User r = user();        // takip isteyen
        follow.follow(r.getId(), t.getId());
        // t -> r'ye ilk DM: "alici (r) gondereni (t) takip ediyor" baglami yalniz KABUL EDILMIS takiptir
        assertFalse(messagePolicy.directAllowed(t.getId(), r.getId()), "bekleyen istek baglam degil");
        requests.accept(t.getId(), r.getId());
        assertTrue(messagePolicy.directAllowed(t.getId(), r.getId()), "kabul edilmis takip baglam");
        assertTrue(messagePolicy.groupInviteAllowed(t.getId(), r.getId()));
    }
}
