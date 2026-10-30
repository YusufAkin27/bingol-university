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
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:77", "Ali", "Yeni mesaj",
                java.util.Map.of("conversationId", "77"));
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:78", "Veli", "Yeni mesaj",
                java.util.Map.of("conversationId", "78"));
        assertEquals(2, notifications.countByUserIdAndReadAtIsNull(u.getId()));

        service.markConversationRead(u.getId(), 77L);

        assertEquals(1, notifications.countByUserIdAndReadAtIsNull(u.getId()));
        assertTrue(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(u.getId(), "conv:77").isEmpty());
        assertTrue(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(u.getId(), "conv:78").isPresent());
    }

    @Test
    void afterReadingTheNextMessageStartsAFreshCounter() {
        User u = user(Instant.now());
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:90", "Ali", "Yeni mesaj", null);
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:90", "Ali", "Yeni mesaj", null);
        assertEquals(2, notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(u.getId(), "conv:90")
                .orElseThrow().getGroupCount());

        service.markConversationRead(u.getId(), 90L);
        service.send(u.getId(), NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:90", "Ali", "Yeni mesaj", null);

        assertEquals(1, notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(u.getId(), "conv:90")
                .orElseThrow().getGroupCount());
    }

    @Test
    void messagePreviewPreferencePersistsAndDefaultsOff() {
        User u = user(Instant.now());
        NotificationPref p = NotificationPref.defaults(u.getId());
        assertFalse(p.isMessagePreview());
        p.setMessagePreview(true);
        prefs.saveAndFlush(p);

        assertTrue(prefs.findById(u.getId()).orElseThrow().isMessagePreview());
    }
}
