package edu.bingol.backend.notification;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.notification.fcm.FcmSender;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;
import java.util.function.Function;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
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
    private final NotificationSubtypePrefRepository subtypePrefs;
    private final DeviceRepository devices;
    private final PushDispatcher dispatcher;
    private final I18n i18n;
    private final PushGate gate;
    private final RecipientGuard guard;

    @Autowired
    public NotificationService(NotificationRepository notifications, NotificationPrefRepository prefs,
                               NotificationSubtypePrefRepository subtypePrefs, DeviceRepository devices,
                               PushDispatcher dispatcher, I18n i18n, PushGate gate, RecipientGuard guard) {
        this.notifications = notifications;
        this.prefs = prefs;
        this.subtypePrefs = subtypePrefs;
        this.devices = devices;
        this.dispatcher = dispatcher;
        this.i18n = i18n;
        this.gate = gate;
        this.guard = guard;
    }

    NotificationService(NotificationRepository notifications, NotificationPrefRepository prefs,
                        NotificationSubtypePrefRepository subtypePrefs, DeviceRepository devices,
                        PushDispatcher dispatcher, I18n i18n) {
        this(notifications, prefs, subtypePrefs, devices, dispatcher, i18n, PushGate.OPEN, RecipientGuard.ALLOW_ALL);
    }

    /** Es zamanli gonderimle (retry'siz) kurar; yalnizca birim testler icin. */
    NotificationService(NotificationRepository notifications, NotificationPrefRepository prefs,
                        NotificationSubtypePrefRepository subtypePrefs, DeviceRepository devices, FcmSender fcm,
                        I18n i18n) {
        this(notifications, prefs, subtypePrefs, devices,
                new PushDispatcher(fcm, devices, Runnable::run, (task, delay) -> { }), i18n, PushGate.OPEN,
                RecipientGuard.ALLOW_ALL);
    }

    /** Hazir metinle tek kullaniciya (icerik zaten dilden bagimsizsa: haber basligi, kullanici girdisi vb.). */
    public void send(Long userId, NotificationType type, String title, String body, Map<String, String> data) {
        // Geriye uyumluluk: ayni konusmanin mesajlari otomatik gruplanir.
        String key = type == NotificationType.MESSAGE && data != null && data.get("conversationId") != null
                ? "conv:" + data.get("conversationId") : null;
        send(userId, type, null, key, title, body, data);
    }

    /**
     * Alt tur ve gruplama anahtariyla tek kullaniciya. Ayni collapseKey ile okunmamis bildirim varsa yenisi
     * eklenmez, o satir guncellenir ve sayaci artar. Sessiz saatte uygulama ici kayit dusulur, push atlanir (SYSTEM haric).
     */
    public void send(Long userId, NotificationType type, NotificationSubtype subtype, String collapseKey,
                     String title, String body, Map<String, String> data) {
        send(userId, type, subtype, collapseKey, title, body, body, data);
    }

    /**
     * Yeni sohbet mesaji: saklanan (uygulama ici) govde HER ZAMAN alicinin dilinde sabit "Yeni mesaj" metnidir;
     * mesaj metni bildirim tablosuna yazilmaz (sifreli saklama bozulmasin). `pushPreview` doluysa yalniz FCM govdesine gider.
     */
    public void sendNewMessage(Long userId, String title, String pushPreview, Map<String, String> data) {
        sendNewMessage(userId, title, pushPreview, data, true);
    }

    /** push=false: yalniz uygulama ici kayit (alici uygulamayi on planda kullaniyor; canli olay zaten gitti). */
    public void sendNewMessage(Long userId, String title, String pushPreview, Map<String, String> data, boolean push) {
        String stored = i18n.msg("notif.message.new", i18n.langOf(userId));
        String key = data != null && data.get("conversationId") != null ? "conv:" + data.get("conversationId") : null;
        NotificationSubtype sub = data == null || data.get("conversationType") == null ? null
                : "GROUP".equals(data.get("conversationType")) ? NotificationSubtype.MESSAGE_GROUP
                : NotificationSubtype.MESSAGE_DIRECT;
        doSend(userId, NotificationType.MESSAGE, sub, key, title, stored,
                pushPreview == null || pushPreview.isBlank() ? stored : pushPreview, data, push);
    }

    /** Saklanan govde (`body`) ile push govdesi (`pushBody`) ayri olabilir. */
    public void send(Long userId, NotificationType type, NotificationSubtype subtype, String collapseKey,
                     String title, String body, String pushBody, Map<String, String> data) {
        doSend(userId, type, subtype, collapseKey, title, body, pushBody, data, true);
    }

    private void doSend(Long userId, NotificationType type, NotificationSubtype subtype, String collapseKey,
                        String title, String body, String pushBody, Map<String, String> data, boolean push) {
        try {
            // Askidaki/silinmis hesaba bildirim yok (SYSTEM = hesap/moderasyon bildirimleri istisna).
            if (type != NotificationType.SYSTEM && !guard.canReceive(userId)) {
                return;
            }
            NotificationPref pref = prefs.findById(userId).orElse(null);
            boolean allowed = subtype != null && subtype.flagBacked()
                    ? pref == null || subtype.flag(pref) // kendi bayragi olan alt tur: ana tur bayragina bakilmaz
                    : enabled(pref, type) && subtypeEnabled(userId, type, subtype);
            if (!allowed) {
                return;
            }
            String key = collapseKey == null ? null : truncate(collapseKey, 120);
            Notification n = key == null ? null
                    : notifications.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(userId, key).orElse(null);
            if (n == null) {
                n = new Notification();
                n.setUserId(userId);
                n.setType(type);
                n.setCollapseKey(key);
            } else {
                n.setGroupCount(n.getGroupCount() + 1);
                n.setCreatedAt(Instant.now());
            }
            n.setSubtype(subtype == null ? null : subtype.name());
            n.setTitle(truncate(title, 200));
            n.setBody(truncate(body, 500));
            String json = toJson(data);
            n.setData(json != null && json.length() > 1000 ? null : json);
            notifications.save(n);

            if (!push) {
                return; // alici uygulamada: yalnizca uygulama ici kayit
            }
            if (type != NotificationType.SYSTEM && QuietHours.isQuiet(pref, Instant.now())) {
                return; // sessiz saat: yalnizca uygulama ici kayit (SYSTEM = hesap guvenligi sessiz saati asar)
            }
            if (!dispatcher.enabled()) {
                return; // FCM kapali: uygulama ici kayit yazildi, push atlanir
            }
            int count = n.getGroupCount();
            if (type == NotificationType.POST_LIKE && count > 1) {
                return; // birlesen begeni: ilk begeniden push gitti, devami yalniz kutuda guncellenir
            }
            String pTitle = title;
            String pBody = pushBody;
            if (type == NotificationType.MESSAGE) {
                if (!gate.allowMessagePush(userId, key == null ? "msg" : key)) {
                    return; // ayni sohbet pencerede / dakikalik ust sinir
                }
                if (count > 1) {
                    pBody = i18n.msg("notif.message.many", i18n.langOf(userId), String.valueOf(count));
                }
            } else {
                if (type != NotificationType.SYSTEM && !gate.allowGeneralPush(userId)) {
                    return;
                }
                if (count > 1) {
                    pTitle = truncate(title, 180) + " (" + count + ")";
                }
            }
            List<String> tokens = devices.findByUserId(userId).stream().map(Device::getFcmToken).toList();
            int badge = (int) notifications.countByUserIdAndReadAtIsNull(userId);
            push(tokens, pTitle, pBody, type, subtype, data, count, key, badge);
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

    /**
     * Sablon anahtariyla (`<key>.title` ve `<key>.body`), alicinin kayitli dilinde. Argumanlar icerik kaynakli
     * metinlerdir (topluluk adi, etkinlik basligi...) ve cevrilmez.
     */
    public void sendTemplated(Long userId, NotificationType type, NotificationSubtype subtype, String key,
                              Map<String, String> data, String... args) {
        Lang lang = i18n.langOf(userId);
        send(userId, type, subtype, null, i18n.msg(key + ".title", lang, (Object[]) args),
                i18n.msg(key + ".body", lang, (Object[]) args), data);
    }

    public void sendTemplated(Long userId, NotificationType type, String key, Map<String, String> data, String... args) {
        Lang lang = i18n.langOf(userId);
        NotificationSubtype sub = NotificationTemplates.find(key).map(NotificationTemplates.Template::subtype).orElse(null);
        send(userId, type, sub, null, i18n.msg(key + ".title", lang, (Object[]) args),
                i18n.msg(key + ".body", lang, (Object[]) args), data);
    }

    /**
     * Kayitli sablonla (NotificationTemplates), alicinin dilinde. Alt tur sablondan gelir; collapseKey null degilse
     * okunmamis benzer bildirimler birlestirilir.
     */
    public void sendTemplate(Long userId, NotificationTemplates.Template t, Map<String, String> data,
                             String collapseKey, String... args) {
        Lang lang = i18n.langOf(userId);
        send(userId, t.type(), t.subtype(), collapseKey, i18n.msg(t.key() + ".title", lang, (Object[]) args),
                i18n.msg(t.key() + ".body", lang, (Object[]) args), data);
    }

    public void broadcast(NotificationType type, String title, String body, Map<String, String> data) {
        try {
            notifications.insertForAll(type.name(), truncate(title, 200), truncate(body, 500), toJson(data),
                    type.prefColumn());
            push(devices.tokensForBroadcast(type.prefColumn()), title, body, type, null, data, 1, null, null);
        } catch (RuntimeException e) {
            log.warn("Toplu bildirim gonderilemedi: {}", e.toString());
        }
    }

    /** Her dil icin ayri metinle toplu gonderim (ornek: "3 yeni haber" / "3 new news items"). */
    public void broadcastLocalized(NotificationType type, Function<Lang, String> title, Function<Lang, String> body,
                                   Map<String, String> data) {
        broadcastLocalized(type, type.prefColumn(), title, body, data);
    }

    /** prefColumn: turun varsayilan tercih sutunu yerine baska bir bayrak (ornek "polls", "academic_announcements"). */
    public void broadcastLocalized(NotificationType type, String prefColumn, Function<Lang, String> title,
                                   Function<Lang, String> body, Map<String, String> data) {
        for (Lang lang : Lang.values()) {
            try {
                String t = title.apply(lang);
                String b = body == null ? null : body.apply(lang);
                notifications.insertForLang(type.name(), truncate(t, 200), truncate(b, 500), toJson(data),
                        prefColumn, lang.code());
                push(devices.tokensForBroadcastLang(prefColumn, lang.code()), t, b, type, null, data, 1, null, null);
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
        return sendBulk(userIds, type, title, body, data, type.prefColumn());
    }

    /** prefColumn: turun varsayilan tercih sutunu yerine baska bir bayrak (ornek "academic_announcements"). */
    public int sendBulk(Collection<Long> userIds, NotificationType type, String title, String body,
                        Map<String, String> data, String prefColumn) {
        int total = 0;
        List<Long> all = new ArrayList<>(userIds);
        for (int i = 0; i < all.size(); i += CHUNK) {
            List<Long> chunk = all.subList(i, Math.min(i + CHUNK, all.size()));
            try {
                List<Long> allowed = prefs.allowing(chunk, prefColumn);
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
                push(devices.tokensForUsers(allowed, prefColumn), title, body, type, null, data, 1, null, null);
            } catch (RuntimeException e) {
                log.warn("Toplu gonderim parcasi basarisiz: {}", e.toString());
            }
        }
        return total;
    }

    private static boolean enabled(NotificationPref p, NotificationType type) {
        if (p == null) {
            return true;
        }
        return switch (type) {
            case NEWS -> p.isNews();
            case ANNOUNCEMENT -> p.isAnnouncements();
            case EVENT -> p.isEvents();
            case MESSAGE -> p.isMessages();
            case COMMUNITY, POST_LIKE, POST_COMMENT, COMMENT_REPLY, POST_MENTION, USER_FOLLOW -> p.isCommunities();
            case SYSTEM -> true;
        };
    }

    /** Alt tur kapatilmissa (satir enabled=false) gonderilmez; SYSTEM ve alt turu olmayanlar etkilenmez. */
    private boolean subtypeEnabled(Long userId, NotificationType type, NotificationSubtype subtype) {
        if (subtype == null || type == NotificationType.SYSTEM) {
            return true;
        }
        return subtypePrefs.findByUserIdAndSubtype(userId, subtype.name()).map(NotificationSubtypePref::isEnabled).orElse(true);
    }

    private void push(List<String> tokens, String title, String body, NotificationType type, NotificationSubtype subtype,
                      Map<String, String> data, int count, String collapseKey, Integer badge) {
        if (tokens.isEmpty()) {
            return;
        }
        Map<String, String> payload = PushPayload.build(type, subtype, data, count);
        dispatcher.dispatch(tokens, PushMessages.of(type, subtype, title, body == null ? "" : body, payload,
                collapseKey, badge));
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
