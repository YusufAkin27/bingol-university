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
        Map<String, String> data = new java.util.LinkedHashMap<>(payload);
        data.put("channelId", channel);
        data.put("threadId", thread);
        // `tag`: Android'de ayni etiketli bildirim yenisiyle degisir (sohbet basina tek bildirim); istemci yerel
        // bildirim kurarsa ayni etiketi kullanmalidir.
        data.put("tag", collapseKey != null ? collapseKey : thread);
        if (collapseKey != null) {
            data.put("collapseKey", collapseKey);
        }
        if (badge != null) {
            data.put("badge", String.valueOf(badge));
        }
        return new PushMessage(title, body, data, collapseKey, thread, channel, type.name(), badge, urgent,
                ttlSeconds(type, subtype));
    }

    /**
     * Cihaz cevrimdisiyken bildirimin saklanma suresi (sn). Gec ulasmasi anlamsiz olanlar kisa tutulur
     * (etkinlik hatirlatmasi 6 sa, begeni/takip 1 gun); sohbet ve sistem 7 gun (telefon kapaliyken gelen mesajlar
     * acilinca ulassin); digerleri 3 gun.
     */
    static int ttlSeconds(NotificationType type, NotificationSubtype subtype) {
        if (subtype == NotificationSubtype.EVENT_REMINDER) {
            return 6 * 3600;
        }
        if (subtype == NotificationSubtype.EXAM_REMINDER) {
            return 3600; // sinava <= 2 sa var: 1 saatten sonra ulasan hatirlatma anlamsiz
        }
        return switch (type) {
            case MESSAGE, SYSTEM -> 7 * 86_400;
            case POST_LIKE, POST_COMMENT, COMMENT_REPLY, POST_MENTION, USER_FOLLOW, EVENT -> 86_400;
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
            case POST_LIKE, POST_COMMENT, COMMENT_REPLY, POST_MENTION, USER_FOLLOW -> CHANNEL_SOCIAL;
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
        if (payload.containsKey("examId")) {
            return "academic"; // sinav hatirlatmalari tek baslik altinda
        }
        return type.name().toLowerCase();
    }
}
