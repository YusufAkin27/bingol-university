package edu.bingol.backend.notification.fcm;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Gercek FCM gonderimi (FcmConfig yalnizca gecerli kimlik bilgisiyle olusturur). */
public class FirebaseFcmSender implements FcmSender {

    private static final Logger log = LoggerFactory.getLogger(FirebaseFcmSender.class);
    /** FCM tek istekte en fazla 500 token kabul eder. */
    private static final int BATCH = 500;
    private static final int MAX_APNS_COLLAPSE_ID = 64;

    private final FirebaseMessaging messaging;
    private final String projectId;

    public FirebaseFcmSender(InputStream credentials) throws IOException {
        FirebaseApp app;
        if (FirebaseApp.getApps().isEmpty()) {
            GoogleCredentials creds = GoogleCredentials.fromStream(credentials);
            FirebaseOptions.Builder ob = FirebaseOptions.builder().setCredentials(creds);
            // Proje kimligi servis hesabi JSON'undaki project_id'den okunur (acikca verilir).
            if (creds instanceof ServiceAccountCredentials sac && sac.getProjectId() != null
                    && !sac.getProjectId().isBlank()) {
                ob.setProjectId(sac.getProjectId());
            }
            app = FirebaseApp.initializeApp(ob.build());
        } else {
            app = FirebaseApp.getInstance();
        }
        this.messaging = FirebaseMessaging.getInstance(app);
        this.projectId = app.getOptions().getProjectId();
        log.info("FCM etkin: Firebase proje kimligi={}", projectId); // proje kimligi gizli degildir; anahtar yazilmaz
    }

    @Override
    public FcmCheck check(boolean dryRun) {
        if (!dryRun) {
            return new FcmCheck(true, false, projectId, null);
        }
        try {
            // Konu mesaji + validateOnly: kimlik/proje/yetki dogrulanir, hicbir cihaza gonderilmez.
            messaging.send(com.google.firebase.messaging.Message.builder().setTopic("bu-validate")
                    .setNotification(Notification.builder().setTitle("validate").setBody("validate").build()).build(), true);
            return new FcmCheck(true, true, projectId, null);
        } catch (FirebaseMessagingException e) {
            String detail = FcmErrorDetail.of(e);
            log.warn("FCM dogrulama basarisiz: {}", detail);
            return new FcmCheck(true, false, projectId,
                    e.getMessagingErrorCode() != null ? e.getMessagingErrorCode().name()
                            : e.getErrorCode() != null ? e.getErrorCode().name() : "ERROR",
                    detail);
        } catch (RuntimeException e) {
            String detail = FcmErrorDetail.of(e);
            log.warn("FCM dogrulama basarisiz: {}", detail);
            return new FcmCheck(true, false, projectId, e.getClass().getSimpleName(), detail);
        }
    }

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data) {
        return send(tokens, title, body, data, null);
    }

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data,
                             String collapseKey) {
        return deliver(tokens, PushMessage.simple(title, body, data, collapseKey)).invalid();
    }

    @Override
    public SendResult deliver(Collection<String> tokens, PushMessage m) {
        List<String> all = new ArrayList<>(tokens);
        List<String> invalid = new ArrayList<>();
        List<String> retryable = new ArrayList<>();
        Map<String, String> codes = new java.util.HashMap<>();
        for (int i = 0; i < all.size(); i += BATCH) {
            List<String> batch = all.subList(i, Math.min(i + BATCH, all.size()));
            try {
                BatchResponse res = messaging.sendEachForMulticast(toMulticast(batch, m));
                collect(batch, res.getResponses(), invalid, retryable, codes);
            } catch (FirebaseMessagingException | RuntimeException e) {
                log.warn("FCM toplu gonderimi basarisiz: {}", FcmErrorDetail.of(e));
                retryable.addAll(batch);
                batch.forEach(t -> codes.put(t, "UNAVAILABLE"));
            }
        }
        return new SendResult(invalid, retryable, codes);
    }

    private static void collect(List<String> batch, List<SendResponse> responses, List<String> invalid,
                                List<String> retryable, Map<String, String> codes) {
        for (int j = 0; j < responses.size(); j++) {
            SendResponse r = responses.get(j);
            if (r.isSuccessful() || r.getException() == null) {
                continue;
            }
            FirebaseMessagingException ex = r.getException();
            String code = ex.getMessagingErrorCode() == null ? "UNAVAILABLE" : ex.getMessagingErrorCode().name();
            switch (FcmErrors.classify(ex.getMessagingErrorCode(), ex.getMessage())) {
                case INVALID_TOKEN -> {
                    invalid.add(batch.get(j));
                    codes.put(batch.get(j), code);
                }
                case RETRYABLE -> {
                    retryable.add(batch.get(j));
                    codes.put(batch.get(j), code);
                }
                default -> log.warn("FCM kalici hata: {}", ex.getMessagingErrorCode());
            }
        }
    }

    private static MulticastMessage toMulticast(List<String> tokens, PushMessage m) {
        return MulticastMessage.builder()
                .setNotification(Notification.builder().setTitle(m.title()).setBody(m.body()).build())
                .putAllData(m.data())
                .setAndroidConfig(android(m))
                .setApnsConfig(apns(m))
                .addAllTokens(tokens)
                .build();
    }

    private static AndroidConfig android(PushMessage m) {
        AndroidNotification.Builder n = AndroidNotification.builder().setSound("default");
        if (m.channelId() != null) {
            n.setChannelId(m.channelId());
        }
        if (m.collapseKey() != null) {
            n.setTag(m.collapseKey());
        } else if (m.threadId() != null) {
            n.setTag(m.threadId());
        }
        AndroidConfig.Builder b = AndroidConfig.builder()
                .setPriority(m.highPriority() ? AndroidConfig.Priority.HIGH : AndroidConfig.Priority.NORMAL)
                .setNotification(n.build());
        if (m.collapseKey() != null) {
            b.setCollapseKey(m.collapseKey());
        }
        return b.build();
    }

    private static ApnsConfig apns(PushMessage m) {
        Aps.Builder aps = Aps.builder().setSound("default").setMutableContent(true);
        if (m.badge() != null) {
            aps.setBadge(m.badge());
        }
        if (m.threadId() != null) {
            aps.setThreadId(m.threadId());
        }
        if (m.category() != null) {
            aps.setCategory(m.category());
        }
        ApnsConfig.Builder b = ApnsConfig.builder()
                .putHeader("apns-push-type", "alert")
                .putHeader("apns-priority", m.highPriority() ? "10" : "5")
                .setAps(aps.build());
        if (m.collapseKey() != null && m.collapseKey().length() <= MAX_APNS_COLLAPSE_ID) {
            b.putHeader("apns-collapse-id", m.collapseKey());
        }
        return b.build();
    }
}
