package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.dbmaint.DbMaintenanceJob;
import edu.bingol.backend.notification.dto.NotificationDtos.NotificationPage;
import edu.bingol.backend.profile.MeSummaryService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Bildirim kutusu sohbet mesajini gostermez/saymaz (mesajlar yalniz push). Eski MESSAGE satirlari (yazilmis olabilir)
 * liste, sayfalama, okunmamis sayisi, "tumunu okundu yap", tur filtresi ve rozet hesabinda yok sayilir; gece isi siler.
 */
@SpringBootTest
class InboxHidesMessagesTest {

    @Autowired NotificationInboxService inbox;
    @Autowired NotificationRepository repo;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;
    @Autowired DbMaintenanceJob dbMaint;
    @Autowired MeSummaryService summary;

    private Long user() {
        User u = new User();
        u.setEmail("n" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi");
        u.setEmailVerified(true);
        return users.saveAndFlush(u).getId();
    }

    private void row(Long uid, NotificationType type, boolean read) {
        Notification n = new Notification();
        n.setUserId(uid);
        n.setType(type);
        n.setTitle(type.name());
        n.setBody("b");
        if (read) {
            n.setReadAt(java.time.Instant.now());
        }
        repo.saveAndFlush(n);
    }

    @Test
    void oldMessageRowsAreInvisibleEverywhereInTheInbox() {
        Long uid = user();
        row(uid, NotificationType.MESSAGE, false);
        row(uid, NotificationType.MESSAGE, false);
        row(uid, NotificationType.FOLLOW_REQUEST, false);
        row(uid, NotificationType.NEWS, false);

        NotificationPage page = inbox.list(uid, null, 20, null, false);
        assertEquals(2, page.items().size());
        assertTrue(page.items().stream().noneMatch(i -> "MESSAGE".equals(String.valueOf(i.type()))));
        assertEquals(2, page.unreadCount(), "sayac yalniz diger turleri sayar");
        assertEquals(2, inbox.unreadCount(uid));
        assertEquals(2, summary.summary(uid).unreadNotifications(), "ana sayfa rozeti de MESSAGE saymaz");

        // sayfalama: MESSAGE satirlari sayfa boslugu uretmez
        NotificationPage first = inbox.list(uid, null, 1, null, false);
        assertEquals(1, first.items().size());
        assertTrue(first.nextCursor() != null);
        assertEquals(1, inbox.list(uid, first.nextCursor(), 1, null, false).items().size());

        // tur filtresi: MESSAGE istenirse gecerli ama bos; FOLLOW_REQUEST gorunur
        assertTrue(inbox.list(uid, null, 20, "MESSAGE", false).items().isEmpty());
        assertEquals(1, inbox.list(uid, null, 20, "FOLLOW_REQUEST", false).items().size());
        assertEquals(2, inbox.list(uid, null, 20, null, true).items().size());
    }

    @Test
    void markAllReadAndBadgeCountsIgnoreMessageRows() {
        Long uid = user();
        row(uid, NotificationType.MESSAGE, false);
        row(uid, NotificationType.FOLLOW_ACCEPTED, false);
        assertEquals(1, repo.countUnreadInbox(uid));
        List<Object[]> badge = repo.unreadCountsOf(List.of(uid));
        assertEquals(1L, badge.get(0)[1], "push rozet sayaci MESSAGE satirini saymaz");

        inbox.markRead(uid, null, true);
        assertEquals(0, inbox.unreadCount(uid));
        // MESSAGE satiri "tumunu okundu" ile dokunulmaz (kutuda zaten yok)
        Integer stillUnread = jdbc.queryForObject(
                "SELECT COUNT(*) FROM notification WHERE user_id = ? AND type = 'MESSAGE' AND read_at IS NULL",
                Integer.class, uid);
        assertEquals(1, stillUnread);
        assertEquals(0, inbox.deleteAll(uid, "MESSAGE", false));
    }

    @Test
    void nightlyJobDeletesLegacyMessageRowsOnly() {
        Long uid = user();
        row(uid, NotificationType.MESSAGE, false);
        row(uid, NotificationType.MESSAGE, true);
        row(uid, NotificationType.NEWS, false);
        java.util.Map<String, Integer> out = dbMaint.runAll();
        assertTrue(out.containsKey("notification_message"));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ? AND type = 'MESSAGE'",
                Integer.class, uid));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ?", Integer.class, uid));
    }
}
