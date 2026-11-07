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

    /** Kulup/etkinlik sessize alma (B5); yoksa (birim testler) filtre uygulanmaz. */
    private NotificationMuteService muteService;

    @Autowired(required = false)
    void setMuteService(NotificationMuteService muteService) {
        this.muteService = muteService;
    }

    private boolean muted(Long userId, NotificationType type, NotificationSubtype sub, Map<String, String> data) {
        return muteService != null && muteService.isMuted(userId, type, sub, data);
    }

    /** Toplu yaz-ya-da-guncelle (PostgreSQL); yoksa ya da desteklenmiyorsa (H2 testleri) alici basina eski yol. */
    private NotificationBatchWriter batchWriter;

    @Autowired(required = false)
    void setBatchWriter(NotificationBatchWriter batchWriter) {
        this.batchWriter = batchWriter;
    }

    /** Toplu sohbet bildiriminin bir alicisi: push gidecek mi ve yalniz push yukune eklenecek anahtarlar. */
    public record MessageTarget(Long userId, boolean push, Map<String, String> pushExtra) {}

    /**
     * Kullanici sohbeti okudu: o sohbetin okunmamis bildirim satiri okundu olur. Yoksa satir sonsuza dek okunmamis
     * kalir, sayaci (`groupCount`) her mesajla buyur ve push govdesi hep "N yeni mesaj" olurdu; rozet de sismis kalirdi.
     */
    public void markConversationRead(Long userId, Long conversationId) {
        try {
            notifications.markReadByCollapseKey(userId, "conv:" + conversationId, Instant.now());
        } catch (RuntimeException e) {
            log.warn("Sohbet bildirimi okundu yapilamadi (kullanici {}): {}", userId, e.toString());
        }
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
        sendNewMessage(userId, title, pushPreview, data, push, null);
    }

    /**
     * pushExtra: yalniz push yukune eklenen anahtarlar (ornek gonderen avatari); bildirim satirinin data JSON'una
     * YAZILMAZ (avatar sonradan gizlenirse eski kayitta URL kalmasin).
     */
    public void sendNewMessage(Long userId, String title, String pushPreview, Map<String, String> data, boolean push,
                               Map<String, String> pushExtra) {
        String stored = i18n.msg("notif.message.new", i18n.langOf(userId));
        String key = data != null && data.get("conversationId") != null ? "conv:" + data.get("conversationId") : null;
        NotificationSubtype sub = data == null || data.get("conversationType") == null ? null
                : "GROUP".equals(data.get("conversationType")) ? NotificationSubtype.MESSAGE_GROUP
                : NotificationSubtype.MESSAGE_DIRECT;
        doSend(userId, NotificationType.MESSAGE, sub, key, title, stored,
                pushPreview == null || pushPreview.isBlank() ? stored : pushPreview, data, push, pushExtra);
    }

    /**
     * Cok alicili sohbet mesaji (T-035): {@link #sendNewMessage} ile AYNI karar tablosu ve sonuc (aktiflik, tercih, alt tur,
     * sessiz saat, PushGate, onizleme izni, "N yeni mesaj"), ama alici basina degil parca basina sorgu: aktiflik+dil,
     * tercih, alt tur tercihi, bildirim satiri (tek `INSERT .. ON CONFLICT`), cihaz token'lari ve rozet sayilari birer
     * IN sorgusudur. `increment`: birlestirilmis dagitimda (ayni sohbette birden cok mesaj) sayaca eklenen mesaj adedi.
     * Veritabani PostgreSQL degilse (H2 testleri) alici basina eski yola duser.
     */
    public void sendNewMessageBatch(List<MessageTarget> targets, String title, String pushPreview,
                                    Map<String, String> data, int increment) {
        if (targets == null || targets.isEmpty()) {
            return;
        }
        if (batchWriter == null || !batchWriter.supported()) {
            for (MessageTarget t : targets) {
                sendNewMessage(t.userId(), title, pushPreview, data, t.push(), t.pushExtra());
            }
            return;
        }
        Map<Long, MessageTarget> byId = new java.util.LinkedHashMap<>();
        targets.forEach(t -> byId.put(t.userId(), t));
        List<MessageTarget> all = new ArrayList<>(byId.values());
        for (int i = 0; i < all.size(); i += BATCH_CHUNK) {
            try {
                messageChunk(all.subList(i, Math.min(i + BATCH_CHUNK, all.size())), title, pushPreview,
                        data, Math.max(1, increment));
            } catch (RuntimeException e) {
                log.warn("Toplu mesaj bildirimi parcasi basarisiz ({} alici): {}", Math.min(BATCH_CHUNK, all.size() - i),
                        e.toString());
            }
        }
    }

    /** Toplu sohbet bildirimi parca boyutu: IN listeleri ve tek ifadelik yazim icin. */
    static final int BATCH_CHUNK = 250;

    /** Parca icinde push'a aday alici (satir yazildi; kapilar gecildi). */
    private record PushCandidate(MessageTarget target, Lang lang, NotificationPref pref, String stored,
                                 NotificationBatchWriter.Row row) {}

    private void messageChunk(List<MessageTarget> chunk, String title, String pushPreview,
                              Map<String, String> data, int increment) {
        Instant now = Instant.now();
        List<Long> ids = chunk.stream().map(MessageTarget::userId).toList();
        Map<Long, Lang> receivable = guard.receivable(ids); // askidaki/silinmis hesap elenir (1 sorgu)
        if (receivable.isEmpty()) {
            return;
        }
        Map<Long, NotificationPref> prefMap = new java.util.HashMap<>();
        prefs.findAllById(receivable.keySet()).forEach(p -> prefMap.put(p.getUserId(), p)); // 1 sorgu
        String key = data != null && data.get("conversationId") != null ? "conv:" + data.get("conversationId") : null;
        if (key != null) {
            key = truncate(key, 120);
        }
        NotificationSubtype sub = data == null || data.get("conversationType") == null ? null
                : "GROUP".equals(data.get("conversationType")) ? NotificationSubtype.MESSAGE_GROUP
                : NotificationSubtype.MESSAGE_DIRECT;
        java.util.Set<Long> subOff = sub != null && !sub.flagBacked()
                ? new java.util.HashSet<>(notifications.subtypeDisabledAmong(receivable.keySet(), sub.name())) // 1 sorgu
                : java.util.Set.of();
        String json = toJson(data);
        String storedData = json != null && json.length() > 1000 ? null : json;

        // Izinli alicilar dile gore (saklanan govde alicinin dilinde sabit "Yeni mesaj")
        Map<Lang, List<MessageTarget>> byLang = new java.util.EnumMap<>(Lang.class);
        for (MessageTarget t : chunk) {
            Long id = t.userId();
            if (!receivable.containsKey(id)) {
                continue;
            }
            NotificationPref pref = prefMap.get(id);
            boolean allowed = enabled(pref, NotificationType.MESSAGE)
                    && (sub != null && sub.flagBacked() ? pref == null || sub.flag(pref) : !subOff.contains(id));
            if (!allowed) {
                continue;
            }
            Lang lang = receivable.get(id) != null ? receivable.get(id) : i18n.langOf(id);
            byLang.computeIfAbsent(lang, l -> new ArrayList<>()).add(t);
        }

        boolean pushOn = dispatcher.enabled();
        List<PushCandidate> candidates = new ArrayList<>();
        for (Map.Entry<Lang, List<MessageTarget>> e : byLang.entrySet()) {
            Lang lang = e.getKey();
            String stored = i18n.msg("notif.message.new", lang);
            List<Long> langIds = e.getValue().stream().map(MessageTarget::userId).toList();
            // Mesajlar uygulama ici bildirim kutusuna YAZILMAZ (yalniz push): satir yerine sentetik sayac
            Map<Long, NotificationBatchWriter.Row> rows = new java.util.HashMap<>();
            for (MessageTarget t : e.getValue()) {
                rows.put(t.userId(), new NotificationBatchWriter.Row(0L, Math.max(1, increment)));
            }
            for (MessageTarget t : e.getValue()) {
                NotificationBatchWriter.Row row = rows.get(t.userId());
                if (row == null || !t.push() || !pushOn) {
                    continue; // alici uygulamada ya da FCM kapali: yalnizca uygulama ici kayit
                }
                NotificationPref pref = prefMap.get(t.userId());
                if (QuietHours.isQuiet(pref, now)) {
                    continue; // sessiz saat
                }
                if (!gate.allowMessagePush(t.userId(), key == null ? "msg" : key)) {
                    continue; // ayni sohbet pencerede / dakikalik ust sinir
                }
                candidates.add(new PushCandidate(t, lang, pref, stored, row));
            }
        }
        if (candidates.isEmpty()) {
            return;
        }
        List<Long> pushIds = candidates.stream().map(c -> c.target().userId()).toList();
        Map<Long, List<String>> tokens = new java.util.HashMap<>();
        for (Object[] r : notifications.deviceTokensOf(pushIds)) { // 1 sorgu
            tokens.computeIfAbsent((Long) r[0], k -> new ArrayList<>()).add((String) r[1]);
        }
        if (tokens.isEmpty()) {
            return;
        }
        // Rozet = bildirim kutusu okunmamisi (MESSAGE haric) + bu sohbet icin 1 (parca basina 1 sorgu; alici basina
        // sohbet okunmamisi sayimi pahali olurdu: tam sayiyi istemci acilista /api/me/summary ile duzeltir)
        Map<Long, Long> badges = new java.util.HashMap<>();
        for (Object[] r : notifications.unreadCountsOf(tokens.keySet())) {
            badges.put((Long) r[0], (Long) r[1]);
        }
        for (PushCandidate c : candidates) {
            Long uid = c.target().userId();
            List<String> toks = tokens.get(uid);
            if (toks == null || toks.isEmpty()) {
                continue;
            }
            int count = c.row().groupCount();
            String pBody = pushPreview == null || pushPreview.isBlank() ? c.stored() : pushPreview;
            if (count > 1 && java.util.Objects.equals(pBody, c.stored())) {
                pBody = i18n.msg("notif.message.many", c.lang(), String.valueOf(count));
            }
            Map<String, String> pushData = messagePushData(data, c.target().pushExtra());
            pushData.put("recipientId", uid.toString());
            pushData.put("locale", c.lang().code());
            push(toks, title, pBody, NotificationType.MESSAGE, sub, pushData, count, key,
                    (int) (badges.getOrDefault(uid, 0L) + 1));
        }
    }

    /** Push yukune yalniz-push alanlari (avatar, gorsel) eklenir; kaynak haritalar degismez. */
    static Map<String, String> messagePushData(Map<String, String> data, Map<String, String> extra) {
        var out = new java.util.HashMap<String, String>(data == null ? Map.of() : data);
        if (extra != null) out.putAll(extra);
        return out;
    }

    /** Saklanan govde (`body`) ile push govdesi (`pushBody`) ayri olabilir. */
    public void send(Long userId, NotificationType type, NotificationSubtype subtype, String collapseKey,
                     String title, String body, String pushBody, Map<String, String> data) {
        doSend(userId, type, subtype, collapseKey, title, body, pushBody, data, true, null);
    }

    private void doSend(Long userId, NotificationType type, NotificationSubtype subtype, String collapseKey,
                        String title, String body, String pushBody, Map<String, String> data, boolean push,
                        Map<String, String> pushExtra) {
        try {
            // Askidaki/silinmis hesaba bildirim yok (SYSTEM = hesap/moderasyon bildirimleri istisna).
            if (type != NotificationType.SYSTEM && !guard.canReceive(userId)) {
                return;
            }
            data = PushDisplay.withBadge(data, i18n, data != null && data.containsKey("badgeKey") ? i18n.langOf(userId) : null);
            NotificationPref pref = prefs.findById(userId).orElse(null);
            // Kendi bayragi olan alt tur (anket / akademik duyuru): ana tur bayragi DA acik olmali (eski tercihler korunur)
            boolean allowed = enabled(pref, type)
                    && (subtype != null && subtype.flagBacked()
                            ? pref == null || subtype.flag(pref)
                            : subtypeEnabled(userId, type, subtype));
            if (!allowed || muted(userId, type, subtype, data)) {
                return;
            }
            String key = collapseKey == null ? null : truncate(collapseKey, 120);
            String json = toJson(data);
            String storedData = json != null && json.length() > 1000 ? null : json;
            int count;
            if (type == NotificationType.MESSAGE) {
                // Sohbet mesaji uygulama ici bildirim kutusuna YAZILMAZ (kutu takip istegi vb. icindir); yalniz push.
                // Birlestirme push tarafinda collapseKey ile yapilir; "N yeni mesaj" sayaci artik tutulmaz (tek mesaj).
                count = 1;
            } else if (key != null && batchWriter != null && batchWriter.supported()) {
                // PostgreSQL: tek ifadelik yaz-ya-da-guncelle (kismi benzersiz indeks V940); eszamanli iki istek
                // yinelenen satir uretmez ve cagiranin islemini bozacak bir benzersizlik hatasi dogmaz.
                NotificationBatchWriter.Row row = batchWriter.upsertUnread(List.of(userId), type,
                        subtype == null ? null : subtype.name(), key, truncate(title, 200), truncate(body, 500),
                        storedData, 1, Instant.now()).get(userId);
                if (row == null) {
                    throw new IllegalStateException("bildirim satiri yazilamadi");
                }
                count = row.groupCount();
            } else {
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
                n.setData(storedData);
                notifications.save(n);
                count = n.getGroupCount();
            }

            if (!push || type == NotificationType.MESSAGE && !dispatcher.enabled()) {
                return; // alici uygulamada ya da FCM kapali (mesaj icin baska kayit yok)
            }
            if (type != NotificationType.SYSTEM && QuietHours.isQuiet(pref, Instant.now())) {
                return; // sessiz saat: yalnizca uygulama ici kayit (SYSTEM = hesap guvenligi sessiz saati asar)
            }
            if (!dispatcher.enabled()) {
                return; // FCM kapali: uygulama ici kayit yazildi, push atlanir
            }
            if ((type == NotificationType.POST_LIKE || type == NotificationType.FORUM) && count > 1) {
                return; // birlesen begeni / forum yorum yagmuru: ilk bildirimden push gitti, devami yalniz kutuda guncellenir
            }
            String pTitle = title;
            String pBody = pushBody;
            if (type == NotificationType.MESSAGE) {
                if (!gate.allowMessagePush(userId, key == null ? "msg" : key)) {
                    return; // ayni sohbet pencerede / dakikalik ust sinir
                }
                // Tek mesajda metin onizlemesi gider; birlesen mesajlarda "N yeni mesaj"
                if (count > 1 && java.util.Objects.equals(pBody, body)) {
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
            int badge = (int) badgeOf(userId);
            Map<String, String> pushData = messagePushData(data, pushExtra);
            pushData.put("recipientId", userId.toString());
            pushData.put("locale", i18n.langOf(userId).code());
            push(tokens, pTitle, pBody, type, subtype, pushData, count, key, badge);
        } catch (RuntimeException e) {
            log.warn("Bildirim gonderilemedi (kullanici {}): {}", userId, e.toString());
        }
    }

    /** Sohbet okunmamis kaynagi (istege bagli: yoksa rozet yalniz bildirim kutusundan gelir). */
    private org.springframework.beans.factory.ObjectProvider<edu.bingol.backend.messaging.ConversationPrefsService> chatBadge;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setChatBadge(org.springframework.beans.factory.ObjectProvider<edu.bingol.backend.messaging.ConversationPrefsService> chatBadge) {
        this.chatBadge = chatBadge;
    }

    /**
     * Push rozeti = bildirim kutusu okunmamisi (MESSAGE haric) + sohbet okunmamisi (sessize alinmamis konusmalar,
     * `/api/me/summary` unreadMessages ile ayni kaynak). Mesajlar artik kutuya yazilmadigi icin sohbet payi buradan gelir.
     */
    private long badgeOf(Long userId) {
        long inbox = notifications.countUnreadInbox(userId);
        try {
            edu.bingol.backend.messaging.ConversationPrefsService c = chatBadge == null ? null : chatBadge.getIfAvailable();
            return c == null ? inbox : inbox + c.unreadBadge(userId);
        } catch (RuntimeException e) {
            return inbox; // rozet hesabi push gonderimini asla bozmaz
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

    /**
     * Cok alicili SABLONLU bildirim (P04 toplu API): {@link #sendTemplate} ile AYNI karar tablosu (aktiflik, tur ve alt
     * tur tercihi, sessiz saat, PushGate, birlesme anahtari, alici dili) ama alici basina degil parca (250) basina
     * sabit sayida sorgu: aktiflik+dil, tercih, alt tur tercihi, bildirim satiri (tek INSERT ya da `ON CONFLICT`
     * upsert), cihaz token'lari ve rozet sayilari birer IN sorgusudur. Cagiran istek/tx disinda (afterCommit + havuz)
     * cagirmalidir; metot exception sizdirmaz.
     * <p>
     * Tum alicilar ayni birlesme anahtarini paylasir (`collapseKey` null ise birlesme yok). MESSAGE turu desteklenmez
     * ({@link #sendNewMessageBatch} kullanin). Veritabani PostgreSQL degilse (H2 testleri) alici basina eski yola duser.
     * Rozet = bildirim kutusu okunmamisi (sohbet payi eklenmez; istemci acilista /api/me/summary ile duzeltir).
     *
     * @param args sablon argumanlari (icerik kaynakli, cevrilmez)
     * @return uygulama ici kaydi yazilan kullanici sayisi (PostgreSQL disinda: islenen alici sayisi)
     */
    public int sendTemplatedBulk(Collection<Long> userIds, NotificationTemplates.Template t, Map<String, String> data,
                                 String collapseKey, String... args) {
        return sendTemplatedBulkBy(userIds, t, data, collapseKey == null ? null : id -> collapseKey, args);
    }

    /** {@link #sendTemplatedBulk} ile ayni; birlesme anahtari alici basina farkli olabilir (null donen = birlesme yok). */
    public int sendTemplatedBulkBy(Collection<Long> userIds, NotificationTemplates.Template t,
                                   Map<String, String> data, Function<Long, String> collapseKeyFn, String... args) {
        if (userIds == null || userIds.isEmpty() || t == null) {
            return 0;
        }
        if (t.type() == NotificationType.MESSAGE) {
            throw new IllegalArgumentException("MESSAGE turu sendNewMessageBatch ile gonderilir");
        }
        List<Long> all = new ArrayList<>(new java.util.LinkedHashSet<>(userIds));
        all.removeIf(java.util.Objects::isNull);
        if (batchWriter == null || !batchWriter.supported()) {
            for (Long id : all) {
                sendTemplate(id, t, data, collapseKeyFn == null ? null : collapseKeyFn.apply(id), args);
            }
            return all.size();
        }
        int total = 0;
        for (int i = 0; i < all.size(); i += BATCH_CHUNK) {
            List<Long> chunk = all.subList(i, Math.min(i + BATCH_CHUNK, all.size()));
            try {
                total += templatedChunk(chunk, t, data, collapseKeyFn, args);
            } catch (RuntimeException e) {
                log.warn("Toplu sablonlu bildirim parcasi basarisiz ({} alici, {}): {}", chunk.size(), t.key(), e.toString());
            }
        }
        return total;
    }

    /** Parca icinde ayni dil + birlesme anahtarini paylasan alicilar. */
    private record TemplGroup(Lang lang, String key) {}

    /** Yazilan satirin push adayi: ayni metin/sayac/rozet taşıyanlar tek dagitimda toplanir. */
    private record TemplPush(String title, String body, String key, int count, int badge, Map<String, String> data) {}

    private int templatedChunk(List<Long> chunk, NotificationTemplates.Template t, Map<String, String> data,
                               Function<Long, String> keyFn, String[] args) {
        Instant now = Instant.now();
        NotificationType type = t.type();
        NotificationSubtype sub = t.subtype();
        Map<Long, Lang> receivable = new java.util.HashMap<>(guard.receivable(chunk)); // askidaki/silinmis hesap elenir (1 sorgu)
        if (type == NotificationType.SYSTEM) {
            // SYSTEM (hesap/moderasyon) askidaki hesaba da gider: eksik olanlarin dilini tek tek cozeriz (nadir)
            for (Long id : chunk) {
                receivable.computeIfAbsent(id, i18n::langOf);
            }
        }
        if (receivable.isEmpty()) {
            return 0;
        }
        Map<Long, NotificationPref> prefMap = new java.util.HashMap<>();
        prefs.findAllById(receivable.keySet()).forEach(p -> prefMap.put(p.getUserId(), p)); // 1 sorgu
        java.util.Set<Long> subOff = sub != null && !sub.flagBacked() && type != NotificationType.SYSTEM
                ? new java.util.HashSet<>(notifications.subtypeDisabledAmong(receivable.keySet(), sub.name())) // 1 sorgu
                : java.util.Set.of();
        Map<TemplGroup, List<Long>> groups = new java.util.LinkedHashMap<>();
        java.util.Set<Long> muteOff = muteService == null ? java.util.Set.of()
                : muteService.mutedAmong(receivable.keySet(), type, sub, data); // sessize alinanlar (en fazla 2 sorgu)
        for (Long id : chunk) {
            if (!receivable.containsKey(id) || muteOff.contains(id)) {
                continue;
            }
            NotificationPref pref = prefMap.get(id);
            boolean allowed = enabled(pref, type)
                    && (sub != null && sub.flagBacked() ? pref == null || sub.flag(pref) : !subOff.contains(id));
            if (!allowed) {
                continue;
            }
            Lang lang = receivable.get(id) != null ? receivable.get(id) : i18n.langOf(id);
            String k = keyFn == null ? null : keyFn.apply(id);
            groups.computeIfAbsent(new TemplGroup(lang, k == null ? null : truncate(k, 120)), g -> new ArrayList<>()).add(id);
        }

        boolean pushOn = dispatcher.enabled();
        // uid -> (metin, anahtar, sayac); satir yazildiktan sonra push adayi olur
        record Pending(Long uid, String title, String body, String key, int count, Map<String, String> data) {}
        List<Pending> pushCandidates = new ArrayList<>();
        int written = 0;
        for (Map.Entry<TemplGroup, List<Long>> e : groups.entrySet()) {
            Lang lang = e.getKey().lang();
            String key = e.getKey().key();
            String title = i18n.msg(t.key() + ".title", lang, (Object[]) args);
            String body = i18n.msg(t.key() + ".body", lang, (Object[]) args);
            Map<String, String> gData = PushDisplay.withBadge(data, i18n, lang); // rozet metni alicinin dilinde
            String json = toJson(gData);
            String storedData = json != null && json.length() > 1000 ? null : json;
            Map<Long, NotificationBatchWriter.Row> rows = key != null
                    ? batchWriter.upsertUnread(e.getValue(), type, sub == null ? null : sub.name(), key,
                            truncate(title, 200), truncate(body, 500), storedData, 1, now)
                    : batchWriter.insertAll(e.getValue(), type, sub == null ? null : sub.name(), truncate(title, 200),
                            truncate(body, 500), storedData, now);
            written += rows.size();
            if (!pushOn) {
                continue; // FCM kapali: uygulama ici kayit yazildi, push atlanir
            }
            for (Long uid : e.getValue()) {
                NotificationBatchWriter.Row row = rows.get(uid);
                if (row == null) {
                    continue;
                }
                if (type != NotificationType.SYSTEM && QuietHours.isQuiet(prefMap.get(uid), now)) {
                    continue; // sessiz saat: yalniz uygulama ici kayit
                }
                int count = row.groupCount();
                if ((type == NotificationType.POST_LIKE || type == NotificationType.FORUM) && count > 1) {
                    continue; // birlesen begeni / forum yorum yagmuru: ilk bildirimden push gitti
                }
                if (type != NotificationType.SYSTEM && !gate.allowGeneralPush(uid)) {
                    continue;
                }
                pushCandidates.add(new Pending(uid, count > 1 ? truncate(title, 180) + " (" + count + ")" : title,
                        body, key, count, gData));
            }
        }
        if (pushCandidates.isEmpty()) {
            return written;
        }
        Map<Long, List<String>> tokens = new java.util.HashMap<>();
        for (Object[] r : notifications.deviceTokensOf(pushCandidates.stream().map(Pending::uid).toList())) { // 1 sorgu
            tokens.computeIfAbsent((Long) r[0], k -> new ArrayList<>()).add((String) r[1]);
        }
        if (tokens.isEmpty()) {
            return written;
        }
        Map<Long, Long> badges = new java.util.HashMap<>();
        for (Object[] r : notifications.unreadCountsOf(tokens.keySet())) { // 1 sorgu
            badges.put((Long) r[0], (Long) r[1]);
        }
        Map<TemplPush, List<String>> dispatches = new java.util.LinkedHashMap<>();
        for (Pending p : pushCandidates) {
            List<String> toks = tokens.get(p.uid());
            if (toks == null || toks.isEmpty()) {
                continue;
            }
            dispatches.computeIfAbsent(new TemplPush(p.title(), p.body(), p.key(), p.count(),
                    (int) (long) badges.getOrDefault(p.uid(), 0L), p.data()), k -> new ArrayList<>()).addAll(toks);
        }
        dispatches.forEach((k, toks) -> push(toks, k.title(), k.body(), type, sub, k.data(), k.count(), k.key(), k.badge()));
        return written;
    }

    /** Genel yayin icin anahtar-kumeli toplu yazim (PostgreSQL); yoksa (H2 testleri) eski tam tarama yolu. */
    private BroadcastWriter broadcastWriter;

    @Autowired(required = false)
    void setBroadcastWriter(BroadcastWriter broadcastWriter) {
        this.broadcastWriter = broadcastWriter;
    }

    public void broadcast(NotificationType type, String title, String body, Map<String, String> data) {
        if (rangeBroadcast()) {
            broadcastRanges(type, type.prefColumn(), null, title, body, data);
            return;
        }
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
                if (rangeBroadcast()) {
                    broadcastRanges(type, prefColumn, lang.code(), t, b, data);
                    continue;
                }
                notifications.insertForLang(type.name(), truncate(t, 200), truncate(b, 500), toJson(data),
                        prefColumn, lang.code());
                push(devices.tokensForBroadcastLang(prefColumn, lang.code()), t, b, type, null, data, 1, null, null);
            } catch (RuntimeException e) {
                log.warn("Toplu bildirim ({}) gonderilemedi: {}", lang, e.toString());
            }
        }
    }

    private boolean rangeBroadcast() {
        return broadcastWriter != null && broadcastWriter.supported();
    }

    /**
     * Genel yayin, kullanici kimligi araliklariyla (BroadcastWriter.RANGE): her aralikta once uygulama ici kayit, sonra
     * (ayri try) push kuyrugu TEK ifadeyle yazilir. Boylece bir aralikta `statement_timeout` asilirsa o aralikta push de
     * dusmez, sonraki araliklar etkilenmez ve tek bir devasa islem/liste olusmaz. lang null = tum diller.
     */
    private void broadcastRanges(NotificationType type, String prefColumn, String lang, String title, String body,
                                 Map<String, String> data) {
        String t = truncate(title, 200);
        String b = truncate(body, 500);
        String json = toJson(data);
        boolean pushOn = dispatcher.enabled() && dispatcher.rangeBroadcastSupported();
        edu.bingol.backend.notification.fcm.PushMessage message = pushOn
                ? PushMessages.of(type, null, title, body == null ? "" : body, PushPayload.build(type, null, data, 1), null, null)
                : null;
        long after = 0;
        int ranges = 0;
        while (true) {
            Long hi;
            try {
                hi = broadcastWriter.upperBound(after, BroadcastWriter.RANGE);
            } catch (RuntimeException e) {
                log.warn("Toplu bildirim araligi okunamadi (after={}): {}", after, e.toString());
                return;
            }
            if (hi == null) {
                break;
            }
            try {
                broadcastWriter.insertNotifications(type, t, b, json, prefColumn, lang, after, hi);
            } catch (RuntimeException e) {
                log.warn("Toplu bildirim satirlari yazilamadi ({}..{}): {}", after, hi, e.toString());
            }
            if (message != null) {
                try {
                    dispatcher.dispatchRange(message, prefColumn, lang, after, hi);
                } catch (RuntimeException e) {
                    log.warn("Toplu push kuyruga yazilamadi ({}..{}): {}", after, hi, e.toString());
                }
            }
            after = hi;
            ranges++;
        }
        log.debug("Toplu bildirim {} aralikta yazildi (tur={}, dil={})", ranges, type, lang);
    }

    /** Toplu gonderim sonucu: uygulama ici kaydi yazilan kisi sayisi ve parca basarisi (kampanya durumu icin). */
    public record BulkResult(int recipients, int chunks, int failedChunks) {
        /** Hicbir parca basarili olmadi (en az bir parca denendi). */
        public boolean allFailed() {
            return chunks > 0 && failedChunks == chunks;
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
        return sendBulkDetailed(userIds, type, title, body, data, prefColumn).recipients();
    }

    /**
     * {@link #sendBulk} ile ayni; ek olarak kac parcanin basarisiz oldugunu doner (parca hatasi yutulur ve loglanir,
     * diger parcalar surer). Kampanya dagiticisi hepsi basarisizsa FAILED, kismi basarisizlikta uyari isaretler.
     */
    public BulkResult sendBulkDetailed(Collection<Long> userIds, NotificationType type, String title, String body,
                                       Map<String, String> data, String prefColumn) {
        int total = 0;
        int chunks = 0;
        int failed = 0;
        List<Long> all = new ArrayList<>(userIds);
        for (int i = 0; i < all.size(); i += CHUNK) {
            List<Long> chunk = all.subList(i, Math.min(i + CHUNK, all.size()));
            chunks++;
            try {
                List<Long> allowed = prefs.allowing(chunk, prefColumn);
                if (muteService != null && !allowed.isEmpty()) {
                    java.util.Set<Long> off = muteService.mutedAmong(allowed, type, null, data);
                    if (!off.isEmpty()) {
                        allowed = allowed.stream().filter(id -> !off.contains(id)).toList();
                    }
                }
                if (allowed.isEmpty()) {
                    continue;
                }
                if (batchWriter != null && batchWriter.supported()) {
                    // PostgreSQL: tek ifadelik INSERT (IDENTITY anahtarli saveAll satir satir yazardi)
                    total += batchWriter.insertAll(allowed, type, null, truncate(title, 200), truncate(body, 500),
                            toJson(data), Instant.now()).size();
                } else {
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
                }
                push(devices.tokensForUsers(allowed, prefColumn), title, body, type, null, data, 1, null, null);
            } catch (RuntimeException e) {
                failed++;
                log.warn("Toplu gonderim parcasi basarisiz: {}", e.toString());
            }
        }
        return new BulkResult(total, chunks, failed);
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
            case COMMUNITY, POST_LIKE, POST_COMMENT, COMMENT_REPLY, COMMENT_LIKE, POST_MENTION, USER_FOLLOW, FOLLOW_REQUEST,
                 FOLLOW_ACCEPTED, FORUM -> p.isCommunities();
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
    static String toJson(Map<String, String> source) {
        Map<String, String> data = PushDisplay.stored(source); // yalniz-push alanlar kalici data'ya yazilmaz
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
