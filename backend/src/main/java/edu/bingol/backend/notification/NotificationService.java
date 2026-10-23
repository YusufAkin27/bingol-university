package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.FcmSender;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Diger modullerin kullandigi bildirim giris noktasi.
 * <ul>
 *   <li>{@link #send}: tek kullaniciya (uygulama ici kayit + push), kullanicinin tercihine saygi duyar</li>
 *   <li>{@link #broadcast}: tum aktif kullanicilara (yeni haber/duyuru/etkinlik)</li>
 * </ul>
 * Push hatalari asla cagiran akisi bozmaz.
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationRepository notifications;
    private final NotificationPrefRepository prefs;
    private final DeviceRepository devices;
    private final FcmSender fcm;

    public NotificationService(NotificationRepository notifications, NotificationPrefRepository prefs,
                               DeviceRepository devices, FcmSender fcm) {
        this.notifications = notifications;
        this.prefs = prefs;
        this.devices = devices;
        this.fcm = fcm;
    }

    public void send(Long userId, NotificationType type, String title, String body, Map<String, String> data) {
        try {
            if (!enabled(userId, type)) {
                return;
            }
            Notification n = new Notification();
            n.setUserId(userId);
            n.setType(type);
            n.setTitle(truncate(title, 200));
            n.setBody(truncate(body, 500));
            n.setData(toJson(data));
            notifications.save(n);

            List<String> tokens = devices.findByUserId(userId).stream().map(Device::getFcmToken).toList();
            push(tokens, title, body, type, data);
        } catch (RuntimeException e) {
            log.warn("Bildirim gonderilemedi (kullanici {}): {}", userId, e.toString());
        }
    }

    public void broadcast(NotificationType type, String title, String body, Map<String, String> data) {
        try {
            notifications.insertForAll(type.name(), truncate(title, 200), truncate(body, 500), toJson(data),
                    type.prefColumn());
            push(devices.tokensForBroadcast(type.prefColumn()), title, body, type, data);
        } catch (RuntimeException e) {
            log.warn("Toplu bildirim gonderilemedi: {}", e.toString());
        }
    }

    private boolean enabled(Long userId, NotificationType type) {
        NotificationPref p = prefs.findById(userId).orElse(null);
        if (p == null) {
            return true;
        }
        return switch (type) {
            case NEWS -> p.isNews();
            case ANNOUNCEMENT -> p.isAnnouncements();
            case EVENT -> p.isEvents();
            case MESSAGE -> p.isMessages();
            case COMMUNITY -> p.isCommunities();
            case SYSTEM -> true;
        };
    }

    private void push(List<String> tokens, String title, String body, NotificationType type, Map<String, String> data) {
        if (tokens.isEmpty()) {
            return;
        }
        Map<String, String> payload = new java.util.HashMap<>(data == null ? Map.of() : data);
        payload.put("type", type.name());
        List<String> invalid = fcm.send(tokens, title, body == null ? "" : body, payload);
        if (!invalid.isEmpty()) {
            devices.deleteByFcmTokenIn(invalid);
        }
    }

    /** Basit JSON (yalnizca dize degerler); disaridan kullanici girdisi gelmez, yine de kacis yapilir. */
    static String toJson(Map<String, String> data) {
        if (data == null || data.isEmpty()) {
            return null;
        }
        StringJoiner j = new StringJoiner(",", "{", "}");
        data.forEach((k, v) -> j.add("\"" + esc(k) + "\":\"" + esc(v) + "\""));
        return j.toString();
    }

    private static String esc(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n");
    }

    private static String truncate(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max - 1) + "…";
    }
}
