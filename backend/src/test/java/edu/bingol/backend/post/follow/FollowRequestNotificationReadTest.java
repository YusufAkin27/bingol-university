package edu.bingol.backend.post.follow;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.reset;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.NotificationInboxService;
import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import edu.bingol.backend.profile.privacy.PrivacyService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * FOLLOWREQ-NOTIF: sonuclanan takip istegi (kabul, red, geri cekme, otomatik kabul, askida temizlik) hedefin
 * kutusundaki FOLLOW_REQUEST bildirimini SILMEZ, OKUNDU isaretler; unread-count (zil rozeti) duser.
 */
@SpringBootTest
class FollowRequestNotificationReadTest {

    @MockitoBean RateLimiter limiter;

    @Autowired FollowService follow;
    @Autowired FollowRequestService requests;
    @Autowired PrivacyService privacy;
    @Autowired NotificationInboxService inbox;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    @BeforeEach
    void resetLimiter() {
        reset(limiter);
    }

    private User user() {
        User u = new User();
        u.setEmail("n" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi " + UUID.randomUUID().toString().substring(0, 4));
        u.setEmailVerified(true);
        u.setDepartment("Bilgisayar");
        u.setLanguage("tr");
        return users.saveAndFlush(u);
    }

    private User privateUser() {
        User u = user();
        setPrivate(u, true);
        return u;
    }

    private void setPrivate(User u, boolean v) {
        privacy.update(u.getId(), new UpdatePrivacyRequest(null, null, null, null, null, null, v));
    }

    private int total(Long uid) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ? AND type = 'FOLLOW_REQUEST'",
                Integer.class, uid);
        return n == null ? 0 : n;
    }

    private int unread(Long uid) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ? "
                + "AND type = 'FOLLOW_REQUEST' AND read_at IS NULL", Integer.class, uid);
        return n == null ? 0 : n;
    }

    @Test
    void acceptMarksTheRequestNotificationReadAndLowersUnreadCount() {
        User t = privateUser();
        User a = user();
        User b = user();
        follow.follow(a.getId(), t.getId());
        follow.follow(b.getId(), t.getId());
        assertEquals(2, unread(t.getId()));
        assertEquals(2, inbox.unreadCount(t.getId()));

        requests.accept(t.getId(), a.getId());

        assertEquals(2, total(t.getId()), "bildirim silinmez");
        assertEquals(1, unread(t.getId()), "yalniz kabul edilenin bildirimi okundu");
        assertEquals(1, inbox.unreadCount(t.getId()), "zil rozeti duser");
    }

    @Test
    void declineMarksReadAndIsIdempotent() {
        User t = privateUser();
        User a = user();
        follow.follow(a.getId(), t.getId());
        assertEquals(1, inbox.unreadCount(t.getId()));

        requests.decline(t.getId(), a.getId());
        requests.decline(t.getId(), a.getId());

        assertEquals(1, total(t.getId()));
        assertEquals(0, unread(t.getId()));
        assertEquals(0, inbox.unreadCount(t.getId()));
    }

    @Test
    void withdrawAndUnfollowMarkTheTargetsNotificationRead() {
        User t = privateUser();
        User a = user();
        User b = user();
        follow.follow(a.getId(), t.getId());
        follow.follow(b.getId(), t.getId());

        follow.unfollow(a.getId(), t.getId()); // DELETE /users/{id}/follow = istegi geri cek
        assertEquals(1, unread(t.getId()));
        assertEquals(1, inbox.unreadCount(t.getId()));

        requests.withdraw(b.getId(), t.getId());
        assertEquals(0, unread(t.getId()));
        assertEquals(2, total(t.getId()));
        assertEquals(0, inbox.unreadCount(t.getId()));
    }

    @Test
    void otherUsersNotificationsAreUntouched() {
        User t1 = privateUser();
        User t2 = privateUser();
        User a = user();
        follow.follow(a.getId(), t1.getId());
        follow.follow(a.getId(), t2.getId()); // ayni istek sahibi, baska hedef: ayni anahtar, baska kullanici

        requests.accept(t1.getId(), a.getId());

        assertEquals(0, unread(t1.getId()));
        assertEquals(1, unread(t2.getId()), "baska hedefin bildirimi etkilenmez");
        assertEquals(1, inbox.unreadCount(t2.getId()));
    }

    @Test
    void unrelatedNotificationsOfTheTargetStayUnread() {
        User t = privateUser();
        User a = user();
        User b = user();
        follow.follow(a.getId(), t.getId());
        jdbc.update("INSERT INTO notification (user_id, type, title, body, collapse_key, group_count, created_at) "
                + "VALUES (?, 'USER_FOLLOW', 'x', 'y', ?, 1, CURRENT_TIMESTAMP)", t.getId(), "follow:" + b.getId());

        requests.accept(t.getId(), a.getId());

        assertEquals(1, inbox.unreadCount(t.getId()), "yalniz FOLLOW_REQUEST okundu, USER_FOLLOW kaldi");
    }

    @Test
    void privateToPublicMarksAllRequestNotificationsReadInOneGo() {
        User t = privateUser();
        User other = privateUser();
        User outsider = user();
        int n = 5;
        for (int i = 0; i < n; i++) {
            follow.follow(user().getId(), t.getId());
        }
        follow.follow(outsider.getId(), other.getId());
        assertEquals(n, inbox.unreadCount(t.getId()));

        setPrivate(t, false); // gizli -> acik: otomatik kabul

        assertEquals(n, total(t.getId()));
        assertEquals(0, unread(t.getId()));
        assertEquals(0, inbox.unreadCount(t.getId()));
        assertEquals(1, unread(other.getId()), "baska kullanici etkilenmez");
    }

    @Test
    void purgeUserMarksTargetsNotificationsReadAndOwnInbox() {
        User t = privateUser();
        User a = user();
        follow.follow(a.getId(), t.getId());
        assertEquals(1, inbox.unreadCount(t.getId()));

        requests.purgeUser(a.getId()); // istek sahibi askiya alindi/silindi

        assertEquals(0, inbox.unreadCount(t.getId()));
        assertEquals(1, total(t.getId()));
    }

    @Test
    void dropBetweenOnBlockMarksNotificationRead() {
        User t = privateUser();
        User a = user();
        follow.follow(a.getId(), t.getId());

        requests.dropBetween(t.getId(), a.getId());

        assertEquals(0, inbox.unreadCount(t.getId()));
    }

    @Test
    void likeEscapeHelperEscapesWildcards() {
        assertEquals("followreq:", FollowRequestService.escapeLike("followreq:"));
        assertEquals("a\\%b\\_c\\\\d", FollowRequestService.escapeLike("a%b_c\\d"));
    }

    @Test
    void reRequestAfterReadCreatesAFreshUnreadNotification() {
        User t = privateUser();
        User a = user();
        follow.follow(a.getId(), t.getId());
        requests.decline(t.getId(), a.getId());
        assertEquals(0, inbox.unreadCount(t.getId()));

        follow.follow(a.getId(), t.getId()); // red sonrasi yeniden istek

        assertEquals(1, inbox.unreadCount(t.getId()), "yeni istek yeni okunmamis bildirim");
        assertEquals(2, total(t.getId()));
    }
}
