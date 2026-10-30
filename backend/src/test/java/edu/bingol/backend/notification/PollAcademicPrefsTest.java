package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Anket / akademik duyuru tercihleri (V880): gonderim kosulu = ana tur bayragi VE kendi bayragi. Bu sayede yeni
 * sutunlarin DEFAULT TRUE olmasi, ana bayragi onceden kapatmis kullanicilarin davranisini degistirmez (migration'da
 * geri doldurma gerekmez). H2'de migration calismadigindan kosul burada dogrulanir.
 */
@SpringBootTest
class PollAcademicPrefsTest {

    @Autowired NotificationService notifications;
    @Autowired NotificationPrefRepository prefs;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    private User user() {
        User u = new User();
        u.setEmail("pa" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Tercih");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private User withPref(boolean announcements, boolean communities, boolean polls, boolean academic) {
        User u = user();
        NotificationPref p = NotificationPref.defaults(u.getId());
        p.setAnnouncements(announcements);
        p.setCommunities(communities);
        p.setPolls(polls);
        p.setAcademicAnnouncements(academic);
        prefs.saveAndFlush(p);
        return u;
    }

    private int inbox(User u) {
        return jdbc.queryForObject("SELECT count(*) FROM notification WHERE user_id = ?", Integer.class, u.getId());
    }

    @Test
    void newColumnsDefaultToTrueAndOldMobileDefaultsKeepWorking() {
        User u = user();
        NotificationPref p = NotificationPref.defaults(u.getId());
        assertTrue(p.isPolls());
        assertTrue(p.isAcademicAnnouncements());
        notifications.sendTemplated(u.getId(), NotificationType.ANNOUNCEMENT, NotificationSubtype.POLL,
                "notif.poll.opened", Map.of("pollId", "1"), "Anket");
        assertEquals(1, inbox(u)); // tercih satiri yok = hepsi acik
    }

    @Test
    void mainFlagOffBlocksPollEvenWhenOwnFlagIsOn() {
        User off = withPref(false, true, true, true); // duyurular kapali (eski tercih), yeni bayrak varsayilan acik
        User on = withPref(true, true, true, true);
        User ownOff = withPref(true, true, false, true);
        for (User u : List.of(off, on, ownOff)) {
            notifications.sendTemplated(u.getId(), NotificationType.ANNOUNCEMENT, NotificationSubtype.POLL,
                    "notif.poll.opened", Map.of("pollId", "2"), "Anket");
        }
        assertEquals(0, inbox(off));
        assertEquals(1, inbox(on));
        assertEquals(0, inbox(ownOff));
    }

    @Test
    void clubPollFollowsCommunitiesFlagAndPollsFlag() {
        User communitiesOff = withPref(true, false, true, true);
        User ok = withPref(false, true, true, true); // duyurular kapali ama kulup anketi COMMUNITY turu: gider
        for (User u : List.of(communitiesOff, ok)) {
            notifications.sendTemplated(u.getId(), NotificationType.COMMUNITY, NotificationSubtype.POLL,
                    "notif.poll.opened", Map.of("pollId", "3", "communityId", "9"), "Anket");
        }
        assertEquals(0, inbox(communitiesOff));
        assertEquals(1, inbox(ok));
    }

    @Test
    void academicAnnouncementRequiresBothFlags() {
        User offMain = withPref(false, true, true, true);
        User offOwn = withPref(true, true, true, false);
        User on = withPref(true, true, true, true);
        for (User u : List.of(offMain, offOwn, on)) {
            notifications.send(u.getId(), NotificationType.ANNOUNCEMENT, NotificationSubtype.ACADEMIC_ANNOUNCEMENT, null,
                    "Duyuru", "Govde", "Govde", Map.of("announcementId", "5"));
        }
        assertEquals(0, inbox(offMain));
        assertEquals(0, inbox(offOwn));
        assertEquals(1, inbox(on));
    }

    @Test
    void bulkQueriesApplyTheSameRule() {
        User offMain = withPref(false, true, true, true);
        User offOwn = withPref(true, true, false, true);
        User on = withPref(true, true, true, true);
        User noRow = user();
        List<Long> ids = List.of(offMain.getId(), offOwn.getId(), on.getId(), noRow.getId());
        List<Long> polls = prefs.allowing(ids, "polls");
        assertFalse(polls.contains(offMain.getId()));
        assertFalse(polls.contains(offOwn.getId()));
        assertTrue(polls.contains(on.getId()));
        assertTrue(polls.contains(noRow.getId()));
        List<Long> academic = prefs.allowing(ids, "academic_announcements");
        assertFalse(academic.contains(offMain.getId()));
        assertTrue(academic.contains(offOwn.getId())); // yalniz polls kapali: akademik duyuru gider
        assertTrue(academic.contains(on.getId()));
    }

    @Test
    void pushOnlyExtraIsNotStoredInTheInboxData() {
        User u = user();
        notifications.sendNewMessage(u.getId(), "Ali", null, Map.of("conversationId", "7", "messageId", "1",
                "conversationType", "DIRECT"), true, Map.of("senderAvatarUrl", "/files/avatars/x.jpg"));
        String data = jdbc.queryForObject("SELECT data FROM notification WHERE user_id = ?", String.class, u.getId());
        assertTrue(data.contains("conversationId"));
        assertFalse(data.contains("senderAvatarUrl"));
        assertFalse(data.contains("/files/avatars"));
    }
}
