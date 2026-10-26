package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.Map;

/** Bildirim turundan platform ayarlarini (kanal, thread-id, kategori, oncelik) uretir. */
final class PushMessages {

    static final String CHANNEL_CHAT = "chat";
    static final String CHANNEL_ANNOUNCEMENT = "announcement";
    static final String CHANNEL_EVENT = "event";

    private PushMessages() {}

    /** @param payload PushPayload.build ciktisi; badge null ise iOS rozeti degismez */
    static PushMessage of(NotificationType type, String title, String body, Map<String, String> payload,
                          String collapseKey, Integer badge) {
        boolean urgent = type == NotificationType.MESSAGE || type == NotificationType.SYSTEM;
        return new PushMessage(title, body, payload, collapseKey, threadId(type, payload), channel(type), type.name(),
                badge, urgent);
    }

    static String channel(NotificationType type) {
        return switch (type) {
            case MESSAGE -> CHANNEL_CHAT;
            case EVENT -> CHANNEL_EVENT;
            case NEWS, ANNOUNCEMENT, COMMUNITY, SYSTEM -> CHANNEL_ANNOUNCEMENT;
        };
    }

    /** Sohbet ve kulup/etkinlik bildirimleri kendi basliklari altinda gruplanir. */
    static String threadId(NotificationType type, Map<String, String> payload) {
        String conv = payload.get("conversationId");
        if (conv != null) {
            return "conv-" + conv;
        }
        String community = payload.get("communityId");
        if (community != null) {
            return "community-" + community;
        }
        String event = payload.get("eventId");
        if (event != null) {
            return "event-" + event;
        }
        return type.name().toLowerCase();
    }
}
