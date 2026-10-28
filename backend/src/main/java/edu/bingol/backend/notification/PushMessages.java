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

    private PushMessages() {}

    /** @param payload PushPayload.build ciktisi; badge null ise iOS rozeti degismez */
    static PushMessage of(NotificationType type, NotificationSubtype subtype, String title, String body,
                          Map<String, String> payload, String collapseKey, Integer badge) {
        // Yuksek oncelik: mesaj, hesap guvenligi (SYSTEM) ve etkinlik basvuru sonucu; begeni/takip normal.
        boolean urgent = type == NotificationType.MESSAGE || type == NotificationType.SYSTEM
                || subtype == NotificationSubtype.EVENT_ADMISSION;
        String thread = threadId(type, payload);
        String channel = payload.containsKey("pollId") ? CHANNEL_POLL : channel(type);
        Map<String, String> data = new java.util.LinkedHashMap<>(payload);
        data.put("channelId", channel);
        data.put("threadId", thread);
        if (collapseKey != null) {
            data.put("collapseKey", collapseKey);
        }
        return new PushMessage(title, body, data, collapseKey, thread, channel, type.name(), badge, urgent);
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
        return type.name().toLowerCase();
    }
}
