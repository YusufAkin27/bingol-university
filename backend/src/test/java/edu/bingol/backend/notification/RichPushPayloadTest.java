package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class RichPushPayloadTest {
    private PushMessage message(String type, String subtype, Map<String, String> input) {
        NotificationType t = NotificationType.valueOf(type);
        NotificationSubtype s = NotificationSubtype.parse(subtype);
        return PushMessages.of(t, s, "Title", "Body", PushPayload.build(t, s, input, 1), null, 2);
    }

    @Test void callerDataCannotForceNativeDeliveryOrSupplyAReply() {
        var payload = PushPayload.build(NotificationType.MESSAGE, null,
                Map.of("richNotification", "1", "richChat", "1", "replyText", "Injected text", "notificationAction", "reply"), 1);
        assertFalse(payload.containsKey("richNotification"));
        assertFalse(payload.containsKey("richChat"));
        assertFalse(payload.containsKey("replyText"));
        assertFalse(payload.containsKey("notificationAction"));
    }

    @Test void nativeCapabilityIsPersistedAndLegacyRegistrationTurnsItOff() {
        var repository = mock(DeviceRepository.class);
        when(repository.findByFcmToken("token")).thenReturn(java.util.Optional.empty());
        when(repository.findByUserIdOrderByUpdatedAtDesc(1L)).thenReturn(List.of());
        var service = new DeviceService(repository);
        service.register(1L, "token", "ANDROID", "2.0.8", "tr", true);
        var saved = org.mockito.ArgumentCaptor.forClass(Device.class);
        verify(repository).saveAndFlush(saved.capture());
        Device device = saved.getValue();
        assertTrue(device.isRichNotifications());
        when(repository.findByFcmToken("token")).thenReturn(java.util.Optional.of(device));
        service.register(1L, "token", "ANDROID", "2.0.7", "tr");
        assertFalse(device.isRichNotifications());
    }

    @Test void stylesCoverEachSupportedReferenceFamily() {
        assertEquals("CHAT_DIRECT", RichPushPayload.style(Map.of("type", "MESSAGE")));
        assertEquals("CHAT_GROUP", RichPushPayload.style(Map.of("type", "MESSAGE", "conversationType", "GROUP")));
        assertEquals("CHAT_MEDIA", RichPushPayload.style(Map.of("type", "MESSAGE", "imageUrl", "/files/a.jpg")));
        assertEquals("EVENT_REMINDER", RichPushPayload.style(Map.of("type", "EVENT", "subtype", "EVENT_REMINDER")));
        assertEquals("EXAM", RichPushPayload.style(Map.of("type", "ANNOUNCEMENT", "examId", "4")));
        assertEquals("POLL", RichPushPayload.style(Map.of("type", "ANNOUNCEMENT", "pollId", "4")));
        assertEquals("FOLLOW_REQUEST", RichPushPayload.style(Map.of("type", "FOLLOW_REQUEST")));
        assertEquals("SYSTEM", RichPushPayload.style(Map.of("type", "SYSTEM")));
        assertEquals("SECURITY", RichPushPayload.style(Map.of("type", "SYSTEM", "securityKind", "TWOFA_ENABLED")));
        assertEquals("SUPPORT", RichPushPayload.style(Map.of("type", "SYSTEM", "ticketId", "3")));
    }

    @Test void dataOnlyIsExplicitlyGatedAndPartitionedByRecipient() {
        var repository = mock(DeviceRepository.class);
        var modern = new Device(); modern.setUserId(7L); modern.setPlatform("ANDROID"); modern.setFcmToken("modern"); modern.setLocale("tr"); modern.setRichNotifications(true);
        var legacy = new Device(); legacy.setUserId(8L); legacy.setPlatform("ANDROID"); legacy.setFcmToken("legacy"); legacy.setAppVersion("2.0.8");
        when(repository.findByFcmTokenIn(any())).thenReturn(List.of(modern, legacy));
        var sender = new FakeFcmSender();
        var dispatcher = new PushDispatcher(sender, repository, Runnable::run, (task, ms) -> {});
        dispatcher.dispatch(List.of("modern", "legacy"), message("MESSAGE", null, Map.of("conversationId", "3", "messageId", "9")));
        assertEquals(2, sender.messages().size());
        var rich = sender.messages().stream().filter(RichPushPayload::isRich).findFirst().orElseThrow();
        var plain = sender.messages().stream().filter(m -> !RichPushPayload.isRich(m)).findFirst().orElseThrow();
        assertEquals("7", rich.data().get("recipientId"));
        assertEquals("Title", rich.data().get("title"));
        assertFalse(plain.data().containsKey("richNotification"));
        assertFalse(plain.data().containsKey("richChat"), "version alone must never switch a legacy app to data-only delivery");
    }

    @Test void mediaIsSameOriginAndEnrichedPayloadFitsFcm() {
        var input = message("MESSAGE", null, Map.of("conversationId", "1", "imageUrl", "https://other.invalid/a.jpg", "senderAvatarUrl", "/files/a.jpg"));
        var rich = RichPushPayload.enrich(input, "https://campus.example", "en", 5L);
        assertFalse(rich.data().containsKey("imageUrl"));
        assertEquals("https://campus.example/files/a.jpg", rich.data().get("senderAvatarUrl"));
        assertTrue(PushPayload.sizeOf(rich.data()) <= PushPayload.MAX_BYTES);
        assertEquals("5", rich.data().get("recipientId"));
        assertEquals("en", rich.data().get("locale"));
    }
}
