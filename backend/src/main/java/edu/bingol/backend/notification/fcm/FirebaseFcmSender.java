package edu.bingol.backend.notification.fcm;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

/** Gercek FCM gonderimi; `app.fcm.credentials-file` (servis hesabi JSON'u) verilince etkinlesir. */
@Component
@ConditionalOnExpression("!'${app.fcm.credentials-file:}'.isEmpty()")
public class FirebaseFcmSender implements FcmSender {

    private static final Logger log = LoggerFactory.getLogger(FirebaseFcmSender.class);
    /** FCM tek istekte en fazla 500 token kabul eder. */
    private static final int BATCH = 500;

    private final FirebaseMessaging messaging;

    public FirebaseFcmSender(@Value("${app.fcm.credentials-file}") String credentialsFile) throws IOException {
        try (FileInputStream in = new FileInputStream(credentialsFile)) {
            FirebaseApp app = FirebaseApp.getApps().isEmpty()
                    ? FirebaseApp.initializeApp(FirebaseOptions.builder()
                            .setCredentials(GoogleCredentials.fromStream(in)).build())
                    : FirebaseApp.getInstance();
            this.messaging = FirebaseMessaging.getInstance(app);
        }
    }

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data) {
        return send(tokens, title, body, data, null);
    }

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data,
                             String collapseKey) {
        List<String> all = new ArrayList<>(tokens);
        List<String> invalid = new ArrayList<>();
        for (int i = 0; i < all.size(); i += BATCH) {
            List<String> batch = all.subList(i, Math.min(i + BATCH, all.size()));
            try {
                MulticastMessage.Builder mb = MulticastMessage.builder()
                        .setNotification(Notification.builder().setTitle(title).setBody(body).build())
                        .putAllData(data)
                        .addAllTokens(batch);
                if (collapseKey != null) {
                    // Android: collapse_key + tag (bildirim yerinde guncellenir); iOS: apns-collapse-id (en fazla 64 bayt).
                    mb.setAndroidConfig(AndroidConfig.builder().setCollapseKey(collapseKey)
                            .setNotification(AndroidNotification.builder().setTag(collapseKey).build()).build());
                    if (collapseKey.length() <= 64) {
                        mb.setApnsConfig(ApnsConfig.builder().putHeader("apns-collapse-id", collapseKey).build());
                    }
                }
                BatchResponse res = messaging.sendEachForMulticast(mb.build());
                List<SendResponse> responses = res.getResponses();
                for (int j = 0; j < responses.size(); j++) {
                    SendResponse r = responses.get(j);
                    if (!r.isSuccessful() && r.getException() != null
                            && r.getException().getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) {
                        invalid.add(batch.get(j));
                    }
                }
            } catch (FirebaseMessagingException e) {
                log.warn("FCM gonderimi basarisiz: {}", e.toString());
            }
        }
        return invalid;
    }
}
