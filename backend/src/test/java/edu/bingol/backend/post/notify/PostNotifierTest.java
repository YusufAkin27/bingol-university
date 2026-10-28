package edu.bingol.backend.post.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Properties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class PostNotifierTest {

    private final NotificationService notifications = mock(NotificationService.class);
    private final NotificationRepository rows = mock(NotificationRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private Instant now = Instant.parse("2026-01-01T10:00:00Z");
    private final Clock clock = new Clock() {
        @Override public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId z) { return this; }
        @Override public Instant instant() { return now; }
    };
    private PostNotifier notifier;

    @BeforeEach
    void setUp() {
        notifier = new PostNotifier(notifications, rows, i18n, users, blocks, clock);
        User actor = new User();
        actor.setDisplayName("Ayse");
        when(users.findById(anyLong())).thenReturn(Optional.of(actor));
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
        when(i18n.msg(anyString(), any(Lang.class), any(Object[].class))).thenAnswer(i -> {
            Object[] a = i.getArguments();
            StringBuilder sb = new StringBuilder((String) a[0]);
            for (int k = 2; k < a.length; k++) {
                if (a[k] instanceof Object[] arr) {
                    for (Object o : arr) {
                        sb.append('|').append(o);
                    }
                } else {
                    sb.append('|').append(a[k]);
                }
            }
            return sb.toString();
        });
        when(rows.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(anyLong(), anyString()))
                .thenReturn(Optional.empty());
    }

    @Test
    void likeSendsSingleNotificationWithPostTarget() {
        notifier.onLike(2L, 50L, 1L);

        ArgumentCaptor<Map<String, String>> data = ArgumentCaptor.forClass(Map.class);
        ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> body = ArgumentCaptor.forClass(String.class);
        verify(notifications).send(eq(1L), eq(NotificationType.POST_LIKE), eq(NotificationSubtype.POST_LIKE),
                key.capture(), anyString(), body.capture(), data.capture());
        assertTrue(key.getValue().startsWith("postlike:50:"));
        assertEquals("notif.post.like.body|Ayse", body.getValue());
        assertEquals("POST", data.getValue().get("target"));
        assertEquals("50", data.getValue().get("value"));
    }

    @Test
    void likesWithinWindowMergeIntoExistingNotification() {
        Notification existing = new Notification();
        existing.setGroupCount(2); // 3 kişi beğenmiş olacak: ad + 2 diğer
        when(rows.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(eq(1L), anyString()))
                .thenReturn(Optional.of(existing));

        notifier.onLike(2L, 50L, 1L);

        ArgumentCaptor<String> body = ArgumentCaptor.forClass(String.class);
        verify(notifications).send(eq(1L), eq(NotificationType.POST_LIKE), eq(NotificationSubtype.POST_LIKE),
                anyString(), anyString(), body.capture(), anyMap());
        assertEquals("notif.post.like.many.body|Ayse|2", body.getValue());
    }

    @Test
    void collapseKeyChangesAfterTenMinuteWindow() {
        ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
        notifier.onLike(2L, 50L, 1L);
        now = now.plusSeconds(601);
        notifier.onLike(3L, 50L, 1L);
        verify(notifications, times(2)).send(eq(1L), any(NotificationType.class), any(NotificationSubtype.class),
                key.capture(), anyString(), anyString(), anyMap());
        List<String> keys = key.getAllValues();
        assertNotEquals(keys.get(0), keys.get(1));
    }

    @Test
    void ownActionAndBlockedPairsGetNoNotification() {
        notifier.onLike(1L, 50L, 1L);
        when(blocks.isBlocked(2L, 1L)).thenReturn(true);
        notifier.onLike(2L, 50L, 1L);
        verify(notifications, never()).send(anyLong(), any(NotificationType.class), any(), any(), anyString(),
                anyString(), anyMap());
    }

    @Test
    void failuresNeverPropagate() {
        when(users.findById(anyLong())).thenThrow(new IllegalStateException("db"));
        notifier.onLike(2L, 50L, 1L);
    }

    // --- Şablon anahtarları: üç dilde mevcut ---

    private static Properties load(String name) throws IOException {
        Properties p = new Properties();
        try (InputStream in = PostNotifierTest.class.getResourceAsStream("/i18n/" + name);
             InputStreamReader r = new InputStreamReader(in, StandardCharsets.UTF_8)) {
            p.load(r);
        }
        return p;
    }

    @Test
    void templateKeysExistInAllLanguages() throws IOException {
        List<String> keys = List.of("notif.post.like.title", "notif.post.like.body", "notif.post.like.many.body",
                "notif.post.adminedit.title", "notif.post.adminedit.body");
        for (String f : List.of("post.properties", "post_en.properties", "post_ar.properties")) {
            Properties p = load(f);
            for (String k : keys) {
                String v = p.getProperty(k);
                assertTrue(v != null && !v.isBlank(), f + " eksik: " + k);
                assertFalse(v.contains("'"), f + " kesme isareti: " + k);
            }
            assertTrue(p.getProperty("notif.post.like.body").contains("{0}"));
            assertTrue(p.getProperty("notif.post.like.many.body").contains("{1}"));
        }
    }

    @Test
    void followIsNotNotifiedAgainAfterUnfollowRefollow() {
        when(rows.existsByUserIdAndCollapseKey(2L, "follow:1")).thenReturn(true);

        notifier.onFollow(1L, 2L);

        verify(notifications, org.mockito.Mockito.never()).send(anyLong(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void firstFollowIsNotified() {
        when(rows.existsByUserIdAndCollapseKey(2L, "follow:1")).thenReturn(false);

        notifier.onFollow(1L, 2L);

        verify(notifications).send(eq(2L), eq(NotificationType.USER_FOLLOW), eq(NotificationSubtype.USER_FOLLOW),
                eq("follow:1"), any(), any(), any());
    }
}
