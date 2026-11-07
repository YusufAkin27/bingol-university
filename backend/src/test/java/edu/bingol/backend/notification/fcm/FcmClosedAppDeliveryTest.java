package edu.bingol.backend.notification.fcm;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.ApnsConfig;
import edu.bingol.backend.notification.RichPushPayload;
import java.lang.reflect.Field;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * Uygulama KAPALIYKEN teslim: Android zengin cihaza `notification` bloksuz, yuksek oncelikli veri-only mesaj
 * (onMessageReceived calisir, yerel kart cizilir); eski cihaza duz yol; iOS'ta alert + mutable-content + kategori + thread.
 * SDK alanlari ozel oldugundan yansima kullanilir.
 */
class FcmClosedAppDeliveryTest {

    private static Object field(Object o, String name) throws Exception {
        Field f = o.getClass().getDeclaredField(name);
        f.setAccessible(true);
        return f.get(o);
    }

    private static PushMessage like() {
        return new PushMessage("Mehmet beğendi", "Gönderini beğendi",
                Map.of("type", "POST_LIKE", "subtype", "POST_LIKE", "postId", "1", "style", "LIKE"),
                "postlike:1", "post-1", "social", "BU_LIKE", 3, false, 86_400);
    }

    @Test
    void richAndroidIsDataOnlyAndHighPriorityEvenForLowPriorityStyles() throws Exception {
        assertFalse(like().highPriority(), "begeni normal oncelikli");
        PushMessage rich = RichPushPayload.enrich(like(), "https://bukampus.com.tr", "tr", 9L);
        assertTrue(RichPushPayload.isRich(rich));
        assertEquals("LIKE", rich.data().get("style"));
        assertEquals("Mehmet beğendi", rich.data().get("title"));
        assertEquals("Gönderini beğendi", rich.data().get("body"));
        assertEquals("9", rich.data().get("recipientId"));
        assertEquals("BU_LIKE", rich.category());

        AndroidConfig android = FirebaseFcmSender.android(rich);
        // bildirim blogu YOK: arka planda sistem karti zengin karti bozmasin; oncelik HIGH
        assertNull(field(android, "notification"));
        assertThat(String.valueOf(field(android, "priority")).toUpperCase(java.util.Locale.ROOT)).contains("HIGH");
        assertEquals("86400s", String.valueOf(field(android, "ttl")));
    }

    @Test
    void legacyAndroidKeepsPlainNotificationBlockAndNormalPriority() throws Exception {
        PushMessage plain = like();
        assertFalse(RichPushPayload.isRich(plain));
        AndroidConfig android = FirebaseFcmSender.android(plain);
        assertNotNull(field(android, "notification"));
        assertThat(String.valueOf(field(android, "priority"))).contains("normal");
    }

    @Test
    void androidStandardCardGetsBigPictureOnlyForTrustedHttpsImage() throws Exception {
        PushMessage news = new PushMessage("Haber", "Ozet",
                Map.of("type", "NEWS", "newsId", "7", "imageUrl", "https://www.bingol.edu.tr/media/1.jpg"), null, "news",
                "announcement", "BU_ANNOUNCEMENT", null, false, 259_200);
        assertEquals("https://www.bingol.edu.tr/media/1.jpg",
                field(field(FirebaseFcmSender.android(news), "notification"), "image"));
        PushMessage evil = new PushMessage("Haber", "Ozet", Map.of("type", "NEWS", "imageUrl", "http://evil.test/a.jpg"), null,
                "news", "announcement", "BU_ANNOUNCEMENT", null, false, 259_200);
        assertNull(field(field(FirebaseFcmSender.android(evil), "notification"), "image"));
    }

    @SuppressWarnings("unchecked")
    @Test
    void iosGetsMutableContentCategoryThreadAndTopLevelDataOutsideAps() throws Exception {
        PushMessage m = new PushMessage("Etkinlik yarın", "Atölye", Map.of("type", "EVENT", "subtype", "EVENT_REMINDER",
                "style", "EVENT_REMINDER", "eventId", "4", "eventStartsAt", "2026-11-06T11:00:00Z", "location", "Amfi"),
                null, "event-4", "event", "BU_EVENT_REMINDER", 1, true, 21_600);
        ApnsConfig apns = FirebaseFcmSender.apns(m);
        Map<String, Object> payload = (Map<String, Object>) field(apns, "payload");
        Map<String, Object> aps = (Map<String, Object>) payload.get("aps");
        assertEquals(1, ((Number) aps.get("mutable-content")).intValue());
        assertEquals("BU_EVENT_REMINDER", aps.get("category"));
        assertEquals("event-4", aps.get("thread-id"));
        assertFalse(aps.containsKey("location"));
        assertFalse(aps.containsKey("style"));
        // alert (baslik+govde) FCM `notification` blogundan APNs'e cevrilir; veri anahtarlari m.data() ile ust duzeyde gider
        assertEquals("Amfi", m.data().get("location"));
    }

    @SuppressWarnings("unchecked")
    @Test
    void criticalAndExamAreTimeSensitiveWhileSocialStaysPassive() throws Exception {
        PushMessage exam = new PushMessage("Sınav", "2 saat kaldı", Map.of("type", "ANNOUNCEMENT", "style", "EXAM", "examId", "4"),
                null, "academic", "academic", "BU_EXAM", null, true, 3600);
        Map<String, Object> aps = (Map<String, Object>) ((Map<String, Object>) field(FirebaseFcmSender.apns(exam), "payload")).get("aps");
        assertEquals("time-sensitive", aps.get("interruption-level"));

        PushMessage critical = new PushMessage("Güvenlik", "Uyarı", Map.of("type", "SYSTEM", "style", "SECURITY", "severity", "critical"),
                null, "system", "announcement", "BU_SECURITY", null, true, 604_800);
        aps = (Map<String, Object>) ((Map<String, Object>) field(FirebaseFcmSender.apns(critical), "payload")).get("aps");
        assertEquals("time-sensitive", aps.get("interruption-level"));

        aps = (Map<String, Object>) ((Map<String, Object>) field(FirebaseFcmSender.apns(like()), "payload")).get("aps");
        assertEquals("passive", aps.get("interruption-level"));
    }
}
