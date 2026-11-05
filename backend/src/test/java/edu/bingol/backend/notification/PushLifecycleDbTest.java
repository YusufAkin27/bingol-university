package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/** Gercek (H2) sorgular: eski token temizligi aktif kullaniciyi korur; sohbet bildirimi okundu olur; tercih kalici. */
@SpringBootTest
class PushLifecycleDbTest {

    @Autowired DeviceRepository devices;
    @Autowired UserRepository users;
    @Autowired NotificationRepository notifications;
    @Autowired NotificationPrefRepository prefs;
    @Autowired NotificationService service;

    private User user(Instant lastSeen) {
        User u = new User();
        u.setEmail("pl" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Yasam");
        u.setEmailVerified(true);
        u.setLastSeenAt(lastSeen);
        return users.saveAndFlush(u);
    }

    private Device device(User u, String token, Instant lastSeen) {
        Device d = new Device();
        d.setUserId(u.getId());
        d.setFcmToken(token + UUID.randomUUID());
        d.setPlatform("ANDROID");
        d.setLastSeenAt(lastSeen);
        return devices.saveAndFlush(d);
    }

    @Test
    void staleCleanupKeepsDevicesOfRecentlyActiveUsersButDropsAbandonedOnes() {
        Instant old = Instant.now().minus(Duration.ofDays(90));
        User active = user(Instant.now().minus(Duration.ofDays(1)));
        User gone = user(old);
        Device keep = device(active, "keep", old); // istemci kaydi yenilemeyi unutmus ama kullanici aktif
        Device drop = device(gone, "drop", old);

        devices.deleteStale(Instant.now().minus(Duration.ofDays(60)));

        assertTrue(devices.findById(keep.getId()).isPresent());
        assertFalse(devices.findById(drop.getId()).isPresent());
    }

    @Test
    void markConversationReadClosesOnlyThatConversationsUnreadRow() {
        User u = user(Instant.now());
        // Eski surumlerden kalmis MESSAGE satirlari (artik yazilmiyor; gece isi siler): okundu isareti hala calisir
        legacyMessageRow(u, "conv:77");
        legacyMessageRow(u, "conv:78");
        assertEquals(2, notifications.countByUserIdAndReadAtIsNull(u.getId()));

        service.markConversationRead(u.getId(), 77L);

        assertEquals(1, notifications.countByUserIdAndReadAtIsNull(u.getId()));
        assertTrue(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(u.getId(), "conv:77").isEmpty());
        assertTrue(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(u.getId(), "conv:78").isPresent());
    }

    private void legacyMessageRow(User u, String key) {
        Notification n = new Notification();
        n.setUserId(u.getId());
        n.setType(NotificationType.MESSAGE);
        n.setSubtype("MESSAGE_DIRECT");
        n.setCollapseKey(key);
        n.setTitle("Ali");
        n.setBody("Yeni mesaj");
        notifications.saveAndFlush(n);
    }

    @Test
    void newMessagesNeverCreateInboxRowsEvenAfterReading() {
        User u = user(Instant.now());
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:90", "Ali", "Yeni mesaj", null);
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:90", "Ali", "Yeni mesaj", null);
        service.markConversationRead(u.getId(), 90L);
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:90", "Ali", "Yeni mesaj", null);

        assertTrue(notifications.findTop500ByUserIdOrderByIdDesc(u.getId()).isEmpty(), "mesaj yalniz push: kutu satiri yok");
        assertEquals(0, notifications.countUnreadInbox(u.getId()));
    }
}
