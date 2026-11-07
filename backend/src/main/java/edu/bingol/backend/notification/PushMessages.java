package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.Map;

/** Bildirim turundan platform ayarlarini (kanal, thread-id, kategori, oncelik) uretir. */
final class PushMessages {

    /** Android kanal kimlikleri (istemci olusturur): chat HIGH, event HIGH, announcement DEFAULT (haber, duyuru,
     *  kulup, sistem/moderasyon), poll DEFAULT (anket), social LOW (begeni/yorum/takip/etiket). */
    static final String CHANNEL_CHAT = "chat";
    static final String CHANNEL_ANNOUNCEMENT = "announcement";
    static final String CHANNEL_EVENT = "event";
    static final String CHANNEL_POLL = "poll";
    static final String CHANNEL_SOCIAL = "social";
    /** Sinav hatirlatmasi (istemci kanali yerel ders/sinav hatirlatmalariyla ortak, HIGH). */
    static final String CHANNEL_ACADEMIC = "academic";

    private PushMessages() {}

    /** @param payload PushPayload.build ciktisi; badge null ise iOS rozeti degismez */
    static PushMessage of(NotificationType type, NotificationSubtype subtype, String title, String body,
                          Map<String, String> payload, String collapseKey, Integer badge) {
        // Yuksek oncelik: mesaj, hesap guvenligi (SYSTEM) ve etkinlik basvuru sonucu; begeni/takip normal.
        boolean urgent = type == NotificationType.MESSAGE || type == NotificationType.SYSTEM
                || subtype == NotificationSubtype.EVENT_ADMISSION || subtype == NotificationSubtype.EXAM_REMINDER;
        String thread = threadId(type, payload);
        String channel = payload.containsKey("pollId") ? CHANNEL_POLL
                : subtype == NotificationSubtype.EXAM_REMINDER ? CHANNEL_ACADEMIC : channel(type);
        // APNs 4 KB siniri alert (baslik+govde) + ozel anahtarlari birlikte sayar: alert metni dusulup veri kirpilir
        title = clip(title, 200);
        body = clip(body, 600);
        Map<String, String> data = new java.util.LinkedHashMap<>(payload);
        data.put("channelId", channel);
        data.put("threadId", thread);
        // `tag`: Android'de ayni etiketli bildirim yenisiyle degisir; yalniz birlesmesi istenen yerde (collapseKey) konur.
        // Tur/thread adi ASLA etiket olmaz (farkli duyurular tepside birbirini siler, A13-01). Istemci yerel bildirim
        // kurarsa ayni etiketi kullanmalidir.
        if (collapseKey != null) {
            data.put("tag", collapseKey);
        }
        if (collapseKey != null) {
            data.put("collapseKey", collapseKey);
        }
        if (badge != null) {
            data.put("badge", String.valueOf(badge));
        }
        data = PushPayload.fit(data, ALERT_BUDGET - utf8(title) - utf8(body));
        return new PushMessage(title, body, data, collapseKey, thread, channel, "BU_" + RichPushPayload.style(payload), badge, urgent,
                ttlSeconds(type, subtype, payload, java.time.Instant.now()));
    }

    /** APNs 4096 bayttan aps iskeleti (ses, kategori, thread, rozet, mutable-content...) payi dusulmus butce. */
    static final int ALERT_BUDGET = PushPayload.MAX_BYTES - 384;

    private static int utf8(String s) {
        return s == null ? 0 : s.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
    }

    private static String clip(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max - 1) + "…";
    }

    /**
     * Cihaz cevrimdisiyken bildirimin saklanma suresi (sn). Gec ulasmasi anlamsiz olanlar kisa tutulur
     * (etkinlik hatirlatmasi 6 sa, begeni/takip 1 gun); sohbet ve sistem 7 gun (telefon kapaliyken gelen mesajlar
     * acilinca ulassin); digerleri 3 gun.
     */
    /**
     * Etkinlik bildirimi (payload `eventEndsAt` tasiyorsa): bitisten sonra ulasmasi anlamsiz oldugundan TTL, etkinligin
     * bitisine kalan sureyle (en az 60 sn) sinirlanir; platform sinirini asan varsayilan TTL bundan buyuk olamaz.
     * Push sunucuda 4 haftadan uzun tutulmaz; cihaz kapaliyken gec gelen bildirim bitmis etkinligi gostermez.
     */
    static int ttlSeconds(NotificationType type, NotificationSubtype subtype, Map<String, String> payload,
                          java.time.Instant now) {
        int base = ttlSeconds(type, subtype);
        String ends = payload == null ? null : payload.get("eventEndsAt");
        if (type != NotificationType.EVENT || ends == null) {
            return base;
        }
        try {
            long left = java.time.Duration.between(now, java.time.Instant.parse(ends)).getSeconds();
            return (int) Math.max(60L, Math.min(base, left));
        } catch (java.time.format.DateTimeParseException e) {
            return base;
        }
    }

    static int ttlSeconds(NotificationType type, NotificationSubtype subtype) {
        if (subtype == NotificationSubtype.EVENT_REMINDER) {
            return 6 * 3600;
        }
        if (subtype == NotificationSubtype.EXAM_REMINDER) {
            return 3600; // sinava <= 2 sa var: 1 saatten sonra ulasan hatirlatma anlamsiz
        }
        return switch (type) {
            case MESSAGE, SYSTEM -> 7 * 86_400;
            case POST_LIKE, POST_COMMENT, COMMENT_REPLY, COMMENT_LIKE, POST_MENTION, USER_FOLLOW, FOLLOW_REQUEST, FOLLOW_ACCEPTED, EVENT, FORUM -> 86_400;
            case NEWS, ANNOUNCEMENT, COMMUNITY -> 3 * 86_400;
        };
    }

    static PushMessage of(NotificationType type, String title, String body, Map<String, String> payload,
                          String collapseKey, Integer badge) {
        return of(type, null, title, body, payload, collapseKey, badge);
    }

    static String channel(NotificationType type) {
        return switch (type) {
            case MESSAGE -> CHANNEL_CHAT;
            case EVENT -> CHANNEL_EVENT;
            case POST_LIKE, POST_COMMENT, COMMENT_REPLY, COMMENT_LIKE, POST_MENTION, USER_FOLLOW, FOLLOW_REQUEST, FOLLOW_ACCEPTED,
                 FORUM -> CHANNEL_SOCIAL;
            case NEWS, ANNOUNCEMENT, COMMUNITY, SYSTEM -> CHANNEL_ANNOUNCEMENT;
        };
    }

    /** Sohbet ve kulup/etkinlik bildirimleri kendi basliklari altinda gruplanir. */
    static String threadId(NotificationType type, Map<String, String> payload) {
        String conv = payload.get("conversationId");
        if (conv != null) {
            return "conv:" + conv;
        }
        String community = payload.get("communityId");
        if (community != null) {
            return "community-" + community;
        }
        String event = payload.get("eventId");
        if (event != null) {
            return "event-" + event;
        }
        String post = payload.get("postId");
        if (post != null) {
            return "post-" + post;
        }
        String forumTopic = payload.get("topicId");
        if (forumTopic != null && "FORUM".equals(payload.get("type"))) {
            return "forum-" + forumTopic; // ayni konunun bildirimleri tek baslik altinda
        }
        if (payload.containsKey("examId")) {
            return "academic"; // sinav hatirlatmalari tek baslik altinda
        }
        return type.name().toLowerCase(java.util.Locale.ROOT);
    }
}
