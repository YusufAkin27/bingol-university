package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Akilli push: collapse alanlari, kanal/oncelik, debounce, on plan, birlesme, alici korumasi, tercih ve sessiz saat. */
class NotificationSmartPushTest {

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final RecipientGuard guard = mock(RecipientGuard.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private final PushGateTest.MemStore store = new PushGateTest.MemStore();
    private NotificationService svc;

    private static Device device(String t) {
        Device d = new Device();
        d.setFcmToken(t);
        return d;
    }

    @BeforeEach
    void setUp() {
        PushDispatcher dispatcher = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { });
        svc = new NotificationService(notifications, prefs, subtypePrefs, devices, dispatcher, i18n,
                new PushGate(store, 20, 100), guard);
        when(notifications.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));
        when(prefs.findById(anyLong())).thenReturn(Optional.empty());
        when(subtypePrefs.findByUserIdAndSubtype(anyLong(), anyString())).thenReturn(Optional.empty());
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(anyLong(), anyString()))
                .thenReturn(Optional.empty());
        when(devices.findByUserId(1L)).thenReturn(List.of(device("tok-aaaaaaaaaaaaaaaa")));
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
        when(i18n.msg("notif.message.new", Lang.TR)).thenReturn("Yeni mesaj");
        when(guard.canReceive(anyLong())).thenReturn(true);
    }

    private static final Map<String, String> CONV = Map.of("conversationId", "5", "messageId", "9",
            "conversationType", "DIRECT");

    @Test
    void messagePushCarriesCollapseThreadAndChannelFields() {
        svc.sendNewMessage(1L, "Ali", null, CONV);

        PushMessage m = fcm.messages().get(0);
        assertEquals("conv:5", m.collapseKey());
        assertEquals("conv:5", m.threadId());
        assertEquals("chat", m.channelId());
        assertTrue(m.highPriority());
        assertEquals("conv:5", m.data().get("collapseKey"));
        assertEquals("conv:5", m.data().get("threadId"));
        assertEquals("chat", m.data().get("channelId"));
        assertEquals("CONVERSATION", m.data().get("targetType"));
        assertEquals("5", m.data().get("targetId"));
        // alt tur birebir/grup tercihleri icin saklanir (push yukunde subtype yok: gonderim anindaki NotificationSubtype)
        verify(notifications).save(org.mockito.ArgumentMatchers.argThat(
                (Notification n) -> "MESSAGE_DIRECT".equals(n.getSubtype())));
    }

    @Test
    void secondMessageInsideWindowIsSilentButSavedInInbox() {
        svc.sendNewMessage(1L, "Ali", null, CONV);
        svc.sendNewMessage(1L, "Ali", null, CONV);

        assertEquals(1, fcm.messages().size()); // ikinci push pencerede bastirildi
        verify(notifications, times(2)).save(any(Notification.class)); // kutu yine yazildi
    }

    @Test
    void afterWindowPushSummarizesCountInRecipientLanguage() {
        Notification existing = new Notification();
        existing.setGroupCount(2);
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(1L, "conv:5"))
                .thenReturn(Optional.of(existing));
        when(i18n.msg("notif.message.many", Lang.TR, "3")).thenReturn("3 yeni mesaj");

        svc.sendNewMessage(1L, "Ali", null, CONV);

        assertEquals("3 yeni mesaj", fcm.messages().get(0).body());
        assertEquals("Ali", fcm.messages().get(0).title()); // baslikta sayi eki yok
        assertEquals("3", fcm.messages().get(0).data().get("count"));
    }

    @Test
    void foregroundRecipientGetsInboxRowButNoPush() {
        svc.sendNewMessage(1L, "Ali", null, CONV, false);

        verify(notifications).save(any(Notification.class));
        assertTrue(fcm.messages().isEmpty());
    }

    @Test
    void differentConversationsAreNotDebouncedTogether() {
        svc.sendNewMessage(1L, "Ali", null, CONV);
        svc.sendNewMessage(1L, "Veli", null,
                Map.of("conversationId", "6", "messageId", "1", "conversationType", "GROUP"));

        assertEquals(2, fcm.messages().size());
    }

    @Test
    void mergedLikeDoesNotPushAgainButFirstDoes() {
        svc.send(1L, NotificationType.POST_LIKE, NotificationSubtype.POST_LIKE, "postlike:7:1", "T", "B",
                Map.of("postId", "7"));
        assertEquals(1, fcm.messages().size());
        PushMessage first = fcm.messages().get(0);
        assertEquals("social", first.channelId());
        assertFalse(first.highPriority());

        Notification existing = new Notification();
        existing.setGroupCount(1);
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(1L, "postlike:7:1"))
                .thenReturn(Optional.of(existing));
        svc.send(1L, NotificationType.POST_LIKE, NotificationSubtype.POST_LIKE, "postlike:7:1", "T", "B2",
                Map.of("postId", "7"));

        assertEquals(1, fcm.messages().size()); // birlesen begeni push'u yok
        assertEquals(2, existing.getGroupCount()); // ama kutudaki sayac artti
    }

    @Test
    void suspendedOrDeletedRecipientGetsNothingExceptSystem() {
        when(guard.canReceive(1L)).thenReturn(false);

        svc.send(1L, NotificationType.EVENT, "T", "B", Map.of("eventId", "1"));
        verify(notifications, never()).save(any(Notification.class));

        svc.send(1L, NotificationType.SYSTEM, "Uyari", "B", null); // moderasyon/guvenlik bildirimi gider
        verify(notifications).save(any(Notification.class));
    }

    @Test
    void disabledMainFlagAndSubtypeFlagAreRespected() {
        NotificationPref p = NotificationPref.defaults(1L);
        p.setCommunities(false);
        when(prefs.findById(1L)).thenReturn(Optional.of(p));
        svc.send(1L, NotificationType.USER_FOLLOW, NotificationSubtype.USER_FOLLOW, "follow:2", "T", "B", Map.of());
        verify(notifications, never()).save(any(Notification.class));

        when(prefs.findById(1L)).thenReturn(Optional.empty());
        NotificationSubtypePref off = new NotificationSubtypePref();
        off.setEnabled(false);
        when(subtypePrefs.findByUserIdAndSubtype(1L, "MESSAGE_GROUP")).thenReturn(Optional.of(off));
        svc.sendNewMessage(1L, "Ali", null, Map.of("conversationId", "8", "conversationType", "GROUP"));
        verify(notifications, never()).save(any(Notification.class));
    }

    @Test
    void quietHoursSuppressPushButSystemBypasses() {
        NotificationPref p = NotificationPref.defaults(1L);
        p.setQuietEnabled(true);
        p.setTimezone("UTC");
        int now = Instant.now().atZone(ZoneId.of("UTC")).getHour() * 60;
        p.setQuietStart((now + 1440 - 120) % 1440);
        p.setQuietEnd((now + 180) % 1440);
        when(prefs.findById(1L)).thenReturn(Optional.of(p));

        svc.sendNewMessage(1L, "Ali", null, CONV);
        svc.send(1L, NotificationType.ANNOUNCEMENT, "T", "B", Map.of());
        assertTrue(fcm.messages().isEmpty());
        verify(notifications, times(2)).save(any(Notification.class)); // kutu dolu

        svc.send(1L, NotificationType.SYSTEM, "Guvenlik", "B", Map.of());
        assertEquals(1, fcm.messages().size());
        assertEquals("announcement", fcm.messages().get(0).channelId());
        assertTrue(fcm.messages().get(0).highPriority());
    }

    @Test
    void channelsAndPriorities() {
        assertEquals("chat", PushMessages.channel(NotificationType.MESSAGE));
        assertEquals("event", PushMessages.channel(NotificationType.EVENT));
        assertEquals("announcement", PushMessages.channel(NotificationType.COMMUNITY));
        assertEquals("social", PushMessages.channel(NotificationType.USER_FOLLOW));
        assertEquals("social", PushMessages.channel(NotificationType.POST_LIKE));
        assertEquals("announcement", PushMessages.channel(NotificationType.SYSTEM));
        assertEquals("poll", PushMessages.of(NotificationType.COMMUNITY, null, "t", "b",
                Map.of("pollId", "3"), null, null).channelId());
        assertEquals("announcement", PushMessages.channel(NotificationType.NEWS));
        PushMessage admission = PushMessages.of(NotificationType.EVENT, NotificationSubtype.EVENT_ADMISSION, "t", "b",
                Map.of("type", "EVENT"), null, null);
        assertTrue(admission.highPriority());
        PushMessage follow = PushMessages.of(NotificationType.USER_FOLLOW, NotificationSubtype.USER_FOLLOW, "t", "b",
                Map.of("type", "USER_FOLLOW"), "follow:2", null);
        assertFalse(follow.highPriority());
        assertNotNull(follow.data().get("channelId"));
        assertNull(admission.data().get("collapseKey"));
    }
}
