package edu.bingol.backend.notification;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FcmSender;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;
import java.util.function.Function;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Diger modullerin kullandigi bildirim giris noktasi (uygulama ici kayit + push).
 * <ul>
 *   <li>{@link #send} / {@link #sendLocalized}: tek kullaniciya; kullanicinin tercihine saygi duyar</li>
 *   <li>{@link #broadcast} / {@link #broadcastLocalized}: tum aktif kullanicilara</li>
 *   <li>{@link #sendBulk}: verilen kullanici listesine (kampanyalar)</li>
 * </ul>
 * Push hatalari asla cagiran akisi bozmaz.
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);
    /** IN (...) listeleri ve FCM istekleri icin parca boyutu. */
    private static final int CHUNK = 500;

    private final NotificationRepository notifications;
    private final NotificationPrefRepository prefs;
    private final DeviceRepository devices;
    private final FcmSender fcm;
    private final I18n i18n;

    public NotificationService(NotificationRepository notifications, NotificationPrefRepository prefs,
                               DeviceRepository devices, FcmSender fcm, I18n i18n) {
        this.notifications = notifications;
        this.prefs = prefs;
        this.devices = devices;
        this.fcm = fcm;
        this.i18n = i18n;
    }

    /** Hazir metinle tek kullaniciya (icerik zaten dilden bagimsizsa: haber basligi, kullanici girdisi vb.). */
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

    /**
     * Mesaj anahtarlariyla, alicinin kayitli dilinde. bodyKey null olabilir; bodyText verilirse (kullanici/yonetici
     * girdisi) cevrilmeden eklenir.
     */
    public void sendLocalized(Long userId, NotificationType type, String titleKey, String bodyKey, String bodyText,
                              Map<String, String> data) {
        Lang lang = i18n.langOf(userId);
        String body = bodyKey != null ? i18n.msg(bodyKey, lang) : bodyText;
        send(userId, type, i18n.msg(titleKey, lang), body, data);
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

    /** Her dil icin ayri metinle toplu gonderim (ornek: "3 yeni haber" / "3 new news items"). */
    public void broadcastLocalized(NotificationType type, Function<Lang, String> title, Function<Lang, String> body,
                                   Map<String, String> data) {
        for (Lang lang : Lang.values()) {
            try {
                String t = title.apply(lang);
                String b = body == null ? null : body.apply(lang);
                notifications.insertForLang(type.name(), truncate(t, 200), truncate(b, 500), toJson(data),
                        type.prefColumn(), lang.code());
                push(devices.tokensForBroadcastLang(type.prefColumn(), lang.code()), t, b, type, data);
            } catch (RuntimeException e) {
                log.warn("Toplu bildirim ({}) gonderilemedi: {}", lang, e.toString());
            }
        }
    }

    /**
     * Verilen kullanicilara ayni metni gonderir (tercih kapali olanlar atlanir). SYSTEM turu tercihi gecer.
     * @return bildirimin uygulama ici kaydi olusturulan kullanici sayisi
     */
    public int sendBulk(Collection<Long> userIds, NotificationType type, String title, String body,
                        Map<String, String> data) {
        int total = 0;
        List<Long> all = new ArrayList<>(userIds);
        for (int i = 0; i < all.size(); i += CHUNK) {
            List<Long> chunk = all.subList(i, Math.min(i + CHUNK, all.size()));
            try {
                List<Long> allowed = prefs.allowing(chunk, type.prefColumn());
                if (allowed.isEmpty()) {
                    continue;
                }
                List<Notification> rows = new ArrayList<>(allowed.size());
                for (Long uid : allowed) {
                    Notification n = new Notification();
                    n.setUserId(uid);
                    n.setType(type);
                    n.setTitle(truncate(title, 200));
                    n.setBody(truncate(body, 500));
                    n.setData(toJson(data));
                    rows.add(n);
                }
                notifications.saveAll(rows);
                total += rows.size();
                push(devices.tokensForUsers(allowed), title, body, type, data);
            } catch (RuntimeException e) {
                log.warn("Toplu gonderim parcasi basarisiz: {}", e.toString());
            }
        }
        return total;
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
        Map<String, String> payload = new HashMap<>(data == null ? Map.of() : data);
        payload.put("type", type.name());
        List<String> invalid = fcm.send(tokens, title, body == null ? "" : body, payload);
        if (!invalid.isEmpty()) {
            devices.deleteByFcmTokenIn(invalid);
        }
    }

    /** Basit JSON (yalnizca dize degerler); kacis yapilir. */
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
