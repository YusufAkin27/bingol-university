package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.notification.fcm.FakeFcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Zengin (veri-mesaji) yolu artik TUM kanallar icin: ayrim, tag, gorsel guvenligi, bayrak, eski cihaz bloku. */
class RichPayloadAllChannelsTest {

    private static final String BASE = "https://bukampus.com.tr";
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final FakeFcmSender fcm = new FakeFcmSender();

    private static Device device(String token, String platform, String version) {
        Device d = new Device();
        d.setFcmToken(token);
        d.setPlatform(platform);
        d.setAppVersion(version);
        return d;
    }

    private PushDispatcher dispatcher(boolean rich) {
        PushDispatcher d = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { });
        org.springframework.test.util.ReflectionTestUtils.setField(d, "richChatEnabled", rich);
        org.springframework.test.util.ReflectionTestUtils.setField(d, "publicWebUrl", BASE);
        return d;
    }

    private static PushMessage event(Map<String, String> extra) {
        Map<String, String> payload = new HashMap<>(PushPayload.build(NotificationType.EVENT,
                NotificationSubtype.EVENT_REMINDER, Map.of("eventId", "7", "card", "EVENT_HOUR"), 1));
        payload.putAll(extra);
        return PushMessages.of(NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER, "Etkinlik 1 saat içinde",
                "Büyük Veri", payload, null, 2);
    }

    @Test
    void flagOffKeepsEveryChannelOnStandardNotificationBlock() {
        when(devices.findByFcmTokenIn(anyCollection())).thenReturn(List.of(device("new-token-aaaaaaaa", "ANDROID", "2.0.8")));
        dispatcher(false).dispatch(List.of("new-token-aaaaaaaa"), event(Map.of()));
        PushMessage m = fcm.messages().get(0);
        assertFalse(RichChatPayload.isRich(m));
        assertEquals("Etkinlik 1 saat içinde", m.title());
        assertEquals("qr_checkin", m.data().get("actions")); // eylemler eski cihaza da veri olarak gider
    }

    @Test
    void flagOnSplitsDevicesByCapabilityForNonChatChannels() {
        when(devices.findByFcmTokenIn(anyCollection())).thenReturn(List.of(
                device("new-token-aaaaaaaa", "ANDROID", "2.0.8"),
                device("old-token-bbbbbbbb", "ANDROID", "2.0.7"),
                device("ios-token-cccccccc", "IOS", "2.0.8")));
        dispatcher(true).dispatch(List.of("new-token-aaaaaaaa", "old-token-bbbbbbbb", "ios-token-cccccccc"), event(Map.of()));
        assertEquals(2, fcm.messages().size());
        PushMessage rich = fcm.messages().stream().filter(RichChatPayload::isRich).findFirst().orElseThrow();
        PushMessage legacy = fcm.messages().stream().filter(x -> !RichChatPayload.isRich(x)).findFirst().orElseThrow();
        assertEquals("event", rich.data().get("channelId"));
        assertEquals("Etkinlik 1 saat içinde", rich.data().get("title"));
        assertEquals("event:7", rich.data().get("tag")); // etkinlik kartlari ayni etkinlik icin tek satira cokar
        assertEquals("qr_checkin", rich.data().get("actions"));
        assertFalse(RichChatPayload.isRich(legacy));
        assertEquals("Büyük Veri", legacy.body());
        // zengin ileti yalniz uygun Android'e, digerleri (eski surum + iOS) standart blokla gider
        assertEquals("1", fcm.sentTo("new-token-aaaaaaaa").get(0).data().get("richChat"));
        assertNull(fcm.sentTo("old-token-bbbbbbbb").get(0).data().get("richChat"));
        assertNull(fcm.sentTo("ios-token-cccccccc").get(0).data().get("richChat"));
    }

    @Test
    void defaultTagsPerChannel() {
        assertEquals("conv:5", RichChatPayload.defaultTag(Map.of("conversationId", "5")));
        assertEquals("security:SECURITY_NEW_DEVICE", RichChatPayload.defaultTag(Map.of("card", "SECURITY_NEW_DEVICE")));
        assertEquals("event:3", RichChatPayload.defaultTag(Map.of("card", "EVENT_DAY", "eventId", "3")));
        assertEquals("poll:9", RichChatPayload.defaultTag(Map.of("card", "POLL_CLOSING", "pollId", "9")));
        assertEquals("news:11", RichChatPayload.defaultTag(Map.of("newsId", "11")));
        assertEquals("ticket:4", RichChatPayload.defaultTag(Map.of("ticketId", "4")));
        assertEquals("unit:8", RichChatPayload.defaultTag(Map.of("unitNewsId", "8")));
        assertEquals("menu:2026-11-02", RichChatPayload.defaultTag(Map.of("card", "MENU_TODAY", "menuDate", "2026-11-02")));
        assertEquals("user:7", RichChatPayload.defaultTag(Map.of("targetType", "USER", "targetId", "7")));
        assertNull(RichChatPayload.defaultTag(Map.of("card", "ANNOUNCEMENT")));
    }

    @Test
    void producerCollapseKeyBecomesTagAndIsNotOverridden() {
        PushMessage m = new PushMessage("T", "B", Map.of("card", "POST_LIKE", "postId", "1"), "postlike:1:5", "post-1",
                "social", "POST_LIKE", 1, false, 60);
        assertEquals("postlike:1:5", RichChatPayload.enrich(m, BASE).data().get("tag"));
    }

    @Test
    void imageUrlAllowsOwnOriginAndUniversityDomainOnly() {
        assertEquals("https://bukampus.com.tr/files/a.jpg", RichChatPayload.imageUrl(BASE, "/files/a.jpg"));
        assertEquals("https://www.bingol.edu.tr/img/h.jpg", RichChatPayload.imageUrl(BASE, "https://www.bingol.edu.tr/img/h.jpg"));
        assertEquals("https://bingol.edu.tr/h.jpg", RichChatPayload.imageUrl(BASE, "https://bingol.edu.tr/h.jpg"));
        assertNull(RichChatPayload.imageUrl(BASE, "https://evilbingol.edu.tr.example.com/h.jpg"));
        assertNull(RichChatPayload.imageUrl(BASE, "https://notbingol.edu.tr/h.jpg"));
        assertNull(RichChatPayload.imageUrl(BASE, "http://www.bingol.edu.tr/h.jpg"));
        assertNull(RichChatPayload.imageUrl(BASE, "https://user@www.bingol.edu.tr/h.jpg"));
    }

    @Test
    void legacyPathAlsoDropsForeignImagesAndAbsolutizes() {
        when(devices.findByFcmTokenIn(anyCollection())).thenReturn(List.of());
        Map<String, String> data = new HashMap<>(Map.of("card", "NEWS", "newsId", "1", "imageStyle", "thumb",
                "imageUrl", "https://evil.test/x.jpg", "senderAvatarUrl", "/files/u.jpg"));
        PushMessage in = new PushMessage("H", "S", data, null, null, "announcement", "NEWS", 1, false, 60);
        dispatcher(false).dispatch(List.of("tok-aaaaaaaaaaaaaaaa"), in);
        PushMessage out = fcm.messages().get(0);
        assertFalse(out.data().containsKey("imageUrl"));
        assertFalse(out.data().containsKey("imageStyle")); // gorselsiz kartta stil anlamsiz
        assertEquals("https://bukampus.com.tr/files/u.jpg", out.data().get("senderAvatarUrl"));
    }

    @Test
    void richFlagOffByDefault() {
        PushDispatcher d = new PushDispatcher(fcm, devices, Runnable::run, (task, ms) -> { });
        assertFalse(d.richEnabled());
    }
}
