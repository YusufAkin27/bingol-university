package edu.bingol.backend.notification.fcm;

import static org.assertj.core.api.Assertions.assertThat;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.ApnsConfig;
import java.lang.reflect.Field;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Android/APNs yuku: collapse_key YOK (tag var), TTL/oncelik/basliklar. SDK alanlari ozel oldugundan yansima kullanilir. */
class FirebaseFcmPayloadTest {

    private static Object field(Object o, String name) throws Exception {
        Field f = o.getClass().getDeclaredField(name);
        f.setAccessible(true);
        return f.get(o);
    }

    private static PushMessage chat() {
        return new PushMessage("Ali", "Yeni mesaj", Map.of("type", "MESSAGE"), "conv:5", "conv:5", "chat", "MESSAGE", 3,
                true, 604_800);
    }

    @Test
    void androidNeverSendsFcmCollapseKeyButKeepsTagTtlAndHighPriority() throws Exception {
        AndroidConfig c = FirebaseFcmSender.android(chat());

        assertThat(field(c, "collapseKey")).isNull(); // >4 anahtar cevrimdisi cihazda mesaj dusurur
        assertThat(String.valueOf(field(c, "ttl"))).isEqualTo("604800s");
        // SDK enum adini kucuk harfe cevirir; tr yerelinde "hIgh" -> yerelden bagimsiz karsilastir
        assertThat(String.valueOf(field(c, "priority")).toUpperCase(java.util.Locale.ROOT)).contains("HIGH");
        Object n = field(c, "notification");
        assertThat(field(n, "tag")).isEqualTo("conv:5");
        assertThat(field(n, "channelId")).isEqualTo("chat");
        assertThat(field(n, "notificationCount")).isEqualTo(3);
    }

    @Test
    void androidWithoutTtlLeavesPlatformDefault() throws Exception {
        PushMessage m = new PushMessage("T", "B", Map.of(), null, "news", "announcement", "NEWS", null, false);

        AndroidConfig c = FirebaseFcmSender.android(m);

        assertThat(field(c, "ttl")).isNull();
        assertThat(String.valueOf(field(c, "priority"))).contains("normal");
        // collapseKey yoksa etiket YOK: tur/thread adi etiket olursa farkli duyurular tepside birbirini siler (A13-01)
        assertThat(field(field(c, "notification"), "tag")).isNull();
    }

    @Test
    void androidSystemConversationNotificationDoesNotShareChatTag() throws Exception {
        // SYSTEM sohbet bildirimi (kapatildi/kaldirildi) conversationId tasir -> thread "conv:5"; mesaj bildirimini silmemeli
        PushMessage m = new PushMessage("T", "B", Map.of(), null, "conv:5", "announcement", "SYSTEM", null, true, 604_800);

        assertThat(field(field(FirebaseFcmSender.android(m), "notification"), "tag")).isNull();
    }

    @Test
    void androidKeepsTagOnlyForIntendedMergeKeys() throws Exception {
        for (String key : new String[] {"conv:5", "follow:7", "postlike:9", "commpost:3"}) {
            PushMessage m = new PushMessage("T", "B", Map.of(), key, "thread", "social", "POST_LIKE", null, false, 86_400);
            assertThat(field(field(FirebaseFcmSender.android(m), "notification"), "tag")).isEqualTo(key);
        }
    }

    @SuppressWarnings("unchecked")
    @Test
    void apnsCarriesPriorityExpirationCollapseIdAndThread() throws Exception {
        ApnsConfig a = FirebaseFcmSender.apns(chat());

        Map<String, String> h = (Map<String, String>) field(a, "headers");
        assertThat(h).containsEntry("apns-push-type", "alert").containsEntry("apns-priority", "10")
                .containsEntry("apns-collapse-id", "conv:5").containsKey("apns-expiration");
        assertThat(Long.parseLong(h.get("apns-expiration"))).isGreaterThan(System.currentTimeMillis() / 1000);
    }

    @SuppressWarnings("unchecked")
    @Test
    void socialIsPassiveAndLowPriorityOnIos() throws Exception {
        PushMessage m = new PushMessage("T", "B", Map.of(), "postlike:1", "post-1", "social", "POST_LIKE", null, false, 86_400);

        ApnsConfig a = FirebaseFcmSender.apns(m);

        Map<String, String> h = (Map<String, String>) field(a, "headers");
        assertThat(h).containsEntry("apns-priority", "5");
        Map<String, Object> payload = (Map<String, Object>) field(a, "payload");
        Map<String, Object> aps = (Map<String, Object>) payload.get("aps");
        assertThat(aps.get("interruption-level")).isEqualTo("passive");
        assertThat(aps.get("thread-id")).isEqualTo("post-1");
    }
}
