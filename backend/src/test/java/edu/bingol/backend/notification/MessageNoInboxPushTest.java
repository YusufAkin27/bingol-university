package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.messaging.ConversationPrefsService;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;

/**
 * Sohbet mesaji uygulama ici bildirim kutusuna YAZILMAZ ama push gider (kutu takip istegi vb. icindir). Push kurallari
 * (tercih, sessiz saat, collapseKey, onizleme) NotificationSmartPushTest / NotificationServiceTest'te ayrica sinanir.
 */
class MessageNoInboxPushTest {

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final RecipientGuard guard = mock(RecipientGuard.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private final PushGateTest.MemStore store = new PushGateTest.MemStore();
    private final ConversationPrefsService chat = mock(ConversationPrefsService.class);
    private NotificationService svc;

    private static Device device(String t) {
        Device d = new Device();
        d.setFcmToken(t);
        return d;
    }

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        PushDispatcher dispatcher = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { });
        svc = new NotificationService(notifications, prefs, subtypePrefs, devices, dispatcher, i18n,
                new PushGate(store, 20, 100), guard);
        ObjectProvider<ConversationPrefsService> provider = mock(ObjectProvider.class);
        when(provider.getIfAvailable()).thenReturn(chat);
        svc.setChatBadge(provider);
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
    void newMessageSendsPushButWritesNoInboxRow() {
        svc.sendNewMessage(1L, "Ali", "merhaba", CONV);

        assertEquals(1, fcm.messages().size(), "push gider");
        PushMessage m = fcm.messages().get(0);
        assertEquals("conv:5", m.collapseKey(), "push birlestirme anahtari ayni");
        verify(notifications, never()).save(any(Notification.class));
        verify(notifications, never()).findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(anyLong(), anyString());
    }

    @Test
    void genericSendWithMessageTypeAlsoStaysOutOfTheInbox() {
        svc.send(1L, NotificationType.MESSAGE, "Ali", "selam", Map.of("conversationId", "9", "messageId", "1"));
        assertEquals(1, fcm.messages().size());
        verify(notifications, never()).save(any(Notification.class));
    }

    @Test
    void otherTypesStillLandInTheInbox() {
        svc.send(1L, NotificationType.FOLLOW_REQUEST, NotificationSubtype.FOLLOW_REQUEST, "followreq:2", "Takip isteği",
                "Ali seni takip etmek istiyor", Map.of("target", "FOLLOW_REQUESTS", "value", "2"));
        verify(notifications).save(org.mockito.ArgumentMatchers.argThat(
                (Notification n) -> n.getType() == NotificationType.FOLLOW_REQUEST));
        assertEquals(1, fcm.messages().size());
        assertEquals("FOLLOW_REQUESTS", fcm.messages().get(0).data().get("targetType"));
    }

    @Test
    void pushBadgeCountsInboxWithoutMessagesPlusChatUnread() {
        when(notifications.countUnreadInbox(1L)).thenReturn(2L);
        when(chat.unreadBadge(1L)).thenReturn(5L);
        svc.sendNewMessage(1L, "Ali", null, CONV);
        assertEquals(Integer.valueOf(7), fcm.messages().get(0).badge(), "kutu (MESSAGE haric) 2 + sohbet okunmamisi 5");
        verify(notifications, never()).countByUserIdAndReadAtIsNull(anyLong());
    }

    @Test
    void messageStaysOutOfInboxEvenWhenPushIsSuppressed() {
        // sessize alinmis/tercih kapali yollar da kutu satiri yazmaz
        NotificationPref off = new NotificationPref();
        off.setMessages(false);
        when(prefs.findById(1L)).thenReturn(Optional.of(off));
        svc.sendNewMessage(1L, "Ali", null, CONV);
        assertTrue(fcm.messages().isEmpty());
        verify(notifications, never()).save(any(Notification.class));
    }

    @Test
    void consecutiveMessagesOfOneConversationEachGetTheirOwnPushWithUniqueMessageId() {
        // Pencere kapali (varsayilan 0): ayni sohbette pes pese mesajlar birbirini ezmez
        NotificationService open = new NotificationService(notifications, prefs, subtypePrefs, devices,
                new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { }), i18n,
                new PushGate(store, 0, 100), guard);
        open.sendNewMessage(1L, "Ali", "bir", Map.of("conversationId", "5", "messageId", "9", "conversationType", "DIRECT"));
        open.sendNewMessage(1L, "Ali", "iki", Map.of("conversationId", "5", "messageId", "10", "conversationType", "DIRECT"));

        assertEquals(2, fcm.messages().size());
        PushMessage a = fcm.messages().get(0);
        PushMessage b = fcm.messages().get(1);
        assertEquals("9", a.data().get("messageId"));
        assertEquals("10", b.data().get("messageId"));
        // iOS gruplamasi thread-id ile; ayni konusma ayni baslik altinda, baska konusma ayri
        assertEquals("conv:5", a.threadId());
        assertEquals("conv:5", b.threadId());
        // sistem duzeyinde birlesme yok (apns-collapse-id / Android tag gonderilmez): bkz. FirebaseFcmPayloadTest
        assertEquals("chat", a.channelId());
    }

    @Test
    void differentConversationsGetDifferentThreads() {
        NotificationService open = new NotificationService(notifications, prefs, subtypePrefs, devices,
                new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { }), i18n,
                new PushGate(store, 0, 100), guard);
        open.sendNewMessage(1L, "Ali", "x", Map.of("conversationId", "5", "messageId", "1", "conversationType", "DIRECT"));
        open.sendNewMessage(1L, "Veli", "y", Map.of("conversationId", "6", "messageId", "2", "conversationType", "DIRECT"));
        assertEquals("conv:5", fcm.messages().get(0).threadId());
        assertEquals("conv:6", fcm.messages().get(1).threadId());
    }
}
