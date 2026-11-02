package edu.bingol.backend.notification.fcm;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Field;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** APNs yuku (iOS'u deneyemeyiz, yuku dogru kurariz): eylem kategorisi, mutable-content, fcm_options.image. */
class FirebaseFcmCardPayloadTest {

    private static Object field(Object o, String name) throws Exception {
        Field f = o.getClass().getDeclaredField(name);
        f.setAccessible(true);
        return f.get(o);
    }

    @Test
    void apnsCarriesActionCategoryMutableContentAndImage() throws Exception {
        PushMessage m = new PushMessage("t", "b",
                Map.of("iosCategory", "BU_QR_CHECKIN", "imageUrl", "https://bukampus.com.tr/a.jpg"),
                "event:3", "event-3", "event", "EVENT", 1, true, 3600);
        var apns = FirebaseFcmSender.apns(m);
        String payload = String.valueOf(field(apns, "payload"));
        assertThat(payload).contains("BU_QR_CHECKIN");
        assertThat(payload.toLowerCase()).contains("mutable");
        assertThat(field(field(apns, "fcmOptions"), "image")).isEqualTo("https://bukampus.com.tr/a.jpg");
    }

    @Test
    void apnsWithoutImageHasNoFcmOptionsAndFallsBackToTypeCategory() throws Exception {
        PushMessage m = new PushMessage("t", "b", Map.of(), null, "x", "announcement", "NEWS", null, false);
        var apns = FirebaseFcmSender.apns(m);
        assertThat(field(apns, "fcmOptions")).isNull();
        assertThat(String.valueOf(field(apns, "payload"))).contains("NEWS");
    }

    @Test
    void apnsRejectsNonHttpsImage() throws Exception {
        PushMessage m = new PushMessage("t", "b", Map.of("imageUrl", "http://x/a.jpg"), null, "x", "announcement",
                "NEWS", null, false);
        assertThat(field(FirebaseFcmSender.apns(m), "fcmOptions")).isNull();
    }

    @Test
    void richMessageHasNoNotificationBlockOnAndroidButKeepsDataActions() throws Exception {
        PushMessage m = new PushMessage("t", "b", Map.of("richChat", "1", "actions", "calendar,view"), null, "x",
                "event", "EVENT", null, true, 3600);
        Object cfg = FirebaseFcmSender.android(m);
        assertThat(field(cfg, "notification")).isNull();
    }
}
