package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.PushMessage;
import org.junit.jupiter.api.Test;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;

class RichChatPayloadTest {
    private Device device(String platform, String version) {
        Device d = new Device(); d.setPlatform(platform); d.setAppVersion(version); return d;
    }
    @Test void onlyCapableAndroidDevicesUseDataMessages() {
        assertFalse(RichChatPayload.supports(device("ANDROID", "2.0.7")));
        assertFalse(RichChatPayload.supports(device("IOS", "2.0.8")));
        assertFalse(RichChatPayload.supports(device("ANDROID", null)));
        assertFalse(RichChatPayload.supports(device("ANDROID", "unknown")));
        assertTrue(RichChatPayload.supports(device("android", "2.0.8")));
        assertTrue(RichChatPayload.supports(device("ANDROID", "2.1.0")));
        assertTrue(RichChatPayload.supports(device("ANDROID", "3.0.0")));
    }
    @Test void richPayloadKeepsMessageAndRejectsExternalMedia() {
        PushMessage m = new PushMessage("Ecrin", "Merhaba", Map.of("senderAvatarUrl", "/files/a.jpg", "imageUrl", "https://evil.test/a.jpg"), "conv:1", "conv:1", "chat", null, 1, true, 300);
        PushMessage r = RichChatPayload.enrich(m, "https://bukampus.com.tr");
        assertEquals("Merhaba", r.data().get("body"));
        assertEquals("https://bukampus.com.tr/files/a.jpg", r.data().get("senderAvatarUrl"));
        assertFalse(r.data().containsKey("imageUrl"));
        assertTrue(RichChatPayload.isRich(r));
        assertEquals(m.ttlSeconds(), r.ttlSeconds());
    }
    @Test void unsafeOrUnknownOriginsNeverGetDownloaded() {
        assertNull(RichChatPayload.mediaUrl("https://bukampus.com.tr", "//evil.test/a.jpg"));
        assertNull(RichChatPayload.mediaUrl("https://bukampus.com.tr", "http://bukampus.com.tr/a.jpg"));
        assertNull(RichChatPayload.mediaUrl("", "/files/a.jpg"));
        assertNull(RichChatPayload.mediaUrl("https://bukampus.com.tr", "https://user@bukampus.com.tr/a.jpg"));
    }
    @Test void previewOffStripsPhotoWithoutMutatingSource() {
        Map<String,String> base = Map.of("conversationId", "1", "imageAttachmentId", "8");
        Map<String,String> extra = Map.of("senderAvatarUrl", "/files/a.jpg", "imageUrl", "/signed/thumb");
        var result = NotificationService.messagePushData(base, extra, false);
        assertFalse(result.containsKey("imageUrl"));
        assertFalse(result.containsKey("imageAttachmentId"));
        assertEquals("/files/a.jpg", result.get("senderAvatarUrl"));
        assertTrue(extra.containsKey("imageUrl"));
        assertTrue(NotificationService.messagePushData(base, extra, true).containsKey("imageUrl"));
    }
    @Test void viewOnceAndRemovedAttachmentsNeverEnterPushPreview() {
        var once = new edu.bingol.backend.messaging.media.AttachmentView(1L, "IMAGE", 20, 20, 100L, "image/jpeg", false, "/full", "/thumb", true, false);
        var normal = new edu.bingol.backend.messaging.media.AttachmentView(2L, "IMAGE", 20, 20, 100L, "image/jpeg", false, "/full", "/thumb");
        var removed = new edu.bingol.backend.messaging.media.AttachmentView(3L, "IMAGE", 20, 20, 100L, "image/jpeg", true, "/full", "/thumb");
        assertNull(RichChatPayload.previewAttachmentId(java.util.List.of(once, removed)));
        assertEquals(2L, RichChatPayload.previewAttachmentId(java.util.List.of(once, normal)));
    }
}
