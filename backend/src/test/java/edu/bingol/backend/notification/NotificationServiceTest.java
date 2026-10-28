package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FakeFcmSender;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class NotificationServiceTest {

    private final NotificationRepository notifications = mock(NotificationRepository.class);
    private final NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
    private final NotificationSubtypePrefRepository subtypePrefs = mock(NotificationSubtypePrefRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final FakeFcmSender fcm = new FakeFcmSender();
    private final NotificationService svc = new NotificationService(notifications, prefs, subtypePrefs, devices, fcm, i18n);

    private Device device(String token) {
        Device d = new Device();
        d.setFcmToken(token);
        return d;
    }

    @BeforeEach
    void setUp() {
        when(notifications.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));
        when(prefs.findById(anyLong())).thenReturn(Optional.empty());
        when(subtypePrefs.findByUserIdAndSubtype(anyLong(), anyString())).thenReturn(Optional.empty());
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(anyLong(), anyString()))
                .thenReturn(Optional.empty());
        when(devices.findByUserId(1L)).thenReturn(List.of(device("tok-aaaaaaaaaaaaaaaa")));
        when(i18n.langOf(anyLong())).thenReturn(Lang.TR);
    }

    @Test
    void savesAndPushesWithContractPayload() {
        svc.send(1L, NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE, null, "T", "B", Map.of("eventId", "7"));

        verify(notifications).save(any(Notification.class));
        FakeFcmSender.Sent s = fcm.last();
        assertEquals("EVENT", s.data().get("type"));
        assertEquals("EVENT_UPDATE", s.data().get("subtype"));
        assertEquals("EVENT", s.data().get("target"));
        assertEquals("7", s.data().get("value"));
        assertEquals("7", s.data().get("eventId")); // eski anahtar korunur
    }

    @Test
    void newMessageNotificationNeverStoresPreviewText() {
        when(i18n.msg("notif.message.new", Lang.TR)).thenReturn("Yeni mesaj");
        org.mockito.ArgumentCaptor<Notification> saved = org.mockito.ArgumentCaptor.forClass(Notification.class);

        svc.sendNewMessage(1L, "Ali", "cok gizli onizleme", Map.of("conversationId", "5", "messageId", "9"));

        verify(notifications).save(saved.capture());
        assertEquals("Yeni mesaj", saved.getValue().getBody()); // tabloda metin yok
        assertEquals("cok gizli onizleme", fcm.last().body()); // yalniz push govdesinde
        assertEquals("Ali", fcm.last().title());
    }

    @Test
    void newMessageWithoutPreviewUsesGenericTextEverywhere() {
        when(i18n.msg("notif.message.new", Lang.TR)).thenReturn("Yeni mesaj");

        svc.sendNewMessage(1L, "Ali", null, Map.of("conversationId", "5"));

        assertEquals("Yeni mesaj", fcm.last().body());
    }

    @Test
    void subtypeDisabledSkipsEverything() {
        NotificationSubtypePref off = new NotificationSubtypePref();
        off.setEnabled(false);
        when(subtypePrefs.findByUserIdAndSubtype(1L, "EVENT_REMINDER")).thenReturn(Optional.of(off));

        svc.send(1L, NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER, null, "T", "B", null);
        svc.send(1L, NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE, null, "T", "B", null);

        verify(notifications).save(any(Notification.class)); // yalniz EVENT_UPDATE
        assertEquals(1, fcm.sent().size());
    }

    @Test
    void mainFlagOffSkipsAllSubtypes() {
        NotificationPref p = NotificationPref.defaults(1L);
        p.setMessages(false);
        when(prefs.findById(1L)).thenReturn(Optional.of(p));

        svc.send(1L, NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:1", "T", "B", null);

        verify(notifications, never()).save(any(Notification.class));
        assertTrue(fcm.sent().isEmpty());
    }

    @Test
    void quietHoursKeepInAppRecordButSkipPush() {
        NotificationPref p = NotificationPref.defaults(1L);
        p.setQuietEnabled(true);
        p.setQuietStart(0);
        p.setQuietEnd(1439); // neredeyse tum gun: test saatten bagimsiz
        p.setTimezone("UTC");
        when(prefs.findById(1L)).thenReturn(Optional.of(p));
        // 23:59 disinda sessiz; bu testin 23:59 UTC'ye denk gelme ihtimali ihmal edilebilir ama yine de kosulu esnek tut
        boolean quietNow = QuietHours.isQuiet(p, java.time.Instant.now());

        svc.send(1L, NotificationType.NEWS, "T", "B", null);

        verify(notifications).save(any(Notification.class));
        assertEquals(quietNow ? 0 : 1, fcm.sent().size());
    }

    @Test
    void systemIgnoresQuietHours() {
        NotificationPref p = NotificationPref.defaults(1L);
        p.setQuietEnabled(true);
        p.setQuietStart(0);
        p.setQuietEnd(1439);
        p.setTimezone("UTC");
        when(prefs.findById(1L)).thenReturn(Optional.of(p));

        svc.send(1L, NotificationType.SYSTEM, "T", "B", null);

        assertEquals(1, fcm.sent().size());
    }

    @Test
    void collapsesUnreadWithSameKeyAndCountsUp() {
        Notification existing = new Notification();
        existing.setUserId(1L);
        existing.setType(NotificationType.MESSAGE);
        existing.setGroupCount(2);
        when(notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(1L, "conv:5"))
                .thenReturn(Optional.of(existing));

        svc.send(1L, NotificationType.MESSAGE, NotificationSubtype.MESSAGE_DIRECT, "conv:5", "Ali", "selam", null);

        assertEquals(3, existing.getGroupCount());
        assertEquals("selam", existing.getBody());
        FakeFcmSender.Sent s = fcm.last();
        assertEquals("conv:5", s.collapseKey());
        assertEquals("3", s.data().get("count"));
        assertEquals("Ali", s.title()); // mesajlarda baslik sabit, govde "N yeni mesaj" (mock i18n bos doner)
    }

    @Test
    void legacyMessageSendDerivesConversationCollapseKey() {
        svc.send(1L, NotificationType.MESSAGE, "Ali", "selam", Map.of("conversationId", "9", "messageId", "1"));

        assertEquals("conv:9", fcm.last().collapseKey());
        assertEquals("CONVERSATION", fcm.last().data().get("target"));
        assertEquals("9", fcm.last().data().get("value"));
    }

    @Test
    void firstNotificationHasNoCountKey() {
        svc.send(1L, NotificationType.MESSAGE, "Ali", "selam", Map.of("conversationId", "9"));
        assertNull(fcm.last().data().get("count"));
    }

    @Test
    void invalidTokensAreDeletedAfterPush() {
        fcm.markInvalid("tok-aaaaaaaaaaaaaaaa");

        svc.send(1L, NotificationType.NEWS, "T", "B", null);

        verify(devices).deleteByFcmTokenIn(List.of("tok-aaaaaaaaaaaaaaaa"));
    }

    @Test
    void templatedSendInfersSubtypeFromRegistry() {
        when(i18n.msg(eq("notif.event.reminderHour.title"), eq(Lang.TR), any(Object[].class))).thenReturn("Baslik");
        when(i18n.msg(eq("notif.event.reminderHour.body"), eq(Lang.TR), any(Object[].class))).thenReturn("Govde");

        svc.sendTemplated(1L, NotificationType.EVENT, "notif.event.reminderHour", Map.of("eventId", "3"), "Konf");

        assertEquals("EVENT_REMINDER", fcm.last().data().get("subtype"));
    }

    @Test
    void bulkPushUsesTypeColumnForQuietFiltering() {
        when(prefs.allowing(anyCollection(), anyString())).thenReturn(List.of(1L));
        when(devices.tokensForUsers(anyCollection(), eq("system"))).thenReturn(List.of("tok-bbbbbbbbbbbbbbbb"));

        int n = svc.sendBulk(Set.of(1L), NotificationType.SYSTEM, "T", "B", Map.of("target", "URL", "value", "https://x.y"));

        assertEquals(1, n);
        assertEquals("URL", fcm.last().data().get("target"));
        assertEquals("SYSTEM", fcm.last().data().get("type"));
    }
}
