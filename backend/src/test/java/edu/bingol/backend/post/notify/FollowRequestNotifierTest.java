package edu.bingol.backend.post.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.support.ResourceBundleMessageSource;

/** FOLLOW_REQUEST / FOLLOW_ACCEPTED bildirimleri: alici dilinde (gercek ceviri dosyalariyla), push hedefi, tekillestirme. */
class FollowRequestNotifierTest {

    private final NotificationService notifications = mock(NotificationService.class);
    private final NotificationRepository rows = mock(NotificationRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private PostNotifier notifier;

    @BeforeEach
    void setUp() {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/post");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        notifier = new PostNotifier(notifications, rows, new I18n(ms, users), users, blocks);
        User actor = new User();
        actor.setDisplayName("Ayse");
        when(users.findById(anyLong())).thenReturn(Optional.of(actor));
    }

    private void lang(long uid, String lang) {
        when(users.findLanguage(uid)).thenReturn(Optional.of(lang));
    }

    @Test
    @SuppressWarnings("unchecked")
    void requestGoesToTargetInTheirLanguageWithCollapseKeyAndPushTarget() {
        lang(10, "tr");
        lang(11, "en");
        lang(12, "ar");
        ArgumentCaptor<Map<String, String>> data = ArgumentCaptor.forClass(Map.class);
        notifier.onFollowRequest(5L, 10L);
        verify(notifications).send(eq(10L), eq(NotificationType.FOLLOW_REQUEST), eq(NotificationSubtype.FOLLOW_REQUEST),
                eq("followreq:5"), eq("Takip isteği"), eq("Ayse seni takip etmek istiyor"), data.capture());
        assertEquals("FOLLOW_REQUESTS", data.getValue().get("target"));
        assertEquals("5", data.getValue().get("userId"));

        notifier.onFollowRequest(5L, 11L);
        verify(notifications).send(eq(11L), eq(NotificationType.FOLLOW_REQUEST), eq(NotificationSubtype.FOLLOW_REQUEST),
                eq("followreq:5"), eq("Follow request"), eq("Ayse wants to follow you"), anyMap());

        notifier.onFollowRequest(5L, 12L);
        ArgumentCaptor<String> title = ArgumentCaptor.forClass(String.class);
        verify(notifications).send(eq(12L), eq(NotificationType.FOLLOW_REQUEST), eq(NotificationSubtype.FOLLOW_REQUEST),
                eq("followreq:5"), title.capture(), anyString(), anyMap());
        assertEquals("طلب متابعة", title.getValue());
    }

    @Test
    @SuppressWarnings("unchecked")
    void acceptedGoesToRequesterWithUserTargetOfTheAccepter() {
        lang(20, "en");
        ArgumentCaptor<Map<String, String>> data = ArgumentCaptor.forClass(Map.class);
        notifier.onFollowAccepted(7L, 20L); // 7 kabul etti, 20 istek sahibi
        verify(notifications).send(eq(20L), eq(NotificationType.FOLLOW_ACCEPTED), eq(NotificationSubtype.FOLLOW_ACCEPTED),
                eq("followacc:7"), eq("Follow request accepted"), eq("Ayse accepted your follow request"), data.capture());
        assertEquals("USER", data.getValue().get("target"));
        assertEquals("7", data.getValue().get("value"), "targetId = kabul eden");
    }

    @Test
    void blockedPairsGetNoNotification() {
        lang(10, "tr");
        when(blocks.isBlocked(5L, 10L)).thenReturn(true);
        when(blocks.isBlocked(10L, 5L)).thenReturn(true);
        notifier.onFollowRequest(5L, 10L);
        notifier.onFollowAccepted(10L, 5L);
        verify(notifications, never()).send(anyLong(), any(NotificationType.class), any(NotificationSubtype.class),
                anyString(), anyString(), anyString(), anyMap());
    }
}
