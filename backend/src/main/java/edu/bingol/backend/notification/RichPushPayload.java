package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.util.LinkedHashMap;
import java.util.Map;

/** Data-only notifications are sent only to devices that explicitly advertise the renderer. */
public final class RichPushPayload {
    private RichPushPayload() {}

    public static boolean isRich(PushMessage message) {
        return "1".equals(message.data().get("richNotification")) || RichChatPayload.isRich(message);
    }

    /** Sunucunun belirledigi gorunum turu (sozlesme: docs/changes/push.md); istemciden gelen `style` yok sayilir. */
    public static String style(Map<String, String> data) {
        String type = data.getOrDefault("type", "SYSTEM");
        String subtype = data.getOrDefault("subtype", "");
        if ("MESSAGE".equals(type)) {
            if (data.containsKey("imageUrl")) return "CHAT_MEDIA";
            return "GROUP".equals(data.get("conversationType")) ? "CHAT_GROUP" : "CHAT_DIRECT";
        }
        if (data.containsKey("newsId")) return "ANNOUNCEMENT"; // kaynak sitenin haber/duyuru/etkinligi: etkinlik kaydi degil
        if ("EVENT".equals(type)) {
            if ("CANCELLED".equals(data.get("eventChange"))) return "EVENT_CANCELLED";
            return switch (subtype) {
                case "EVENT_REMINDER" -> "EVENT_REMINDER";
                case "EVENT_ADMISSION" -> "EVENT_ADMISSION";
                default -> "EVENT_UPDATE";
            };
        }
        if (data.containsKey("pollId") || "POLL".equals(subtype)) return "POLL";
        if ("EXAM_REMINDER".equals(subtype) || data.containsKey("examId")) return "EXAM";
        if ("ACADEMIC_ANNOUNCEMENT".equals(subtype)) return "ACADEMIC";
        if ("MEAL_MENU".equals(subtype)) return "MEAL";
        if ("FOLLOW_REQUEST".equals(type)) return "FOLLOW_REQUEST";
        if ("FOLLOW_ACCEPTED".equals(type)) return "FOLLOW_ACCEPTED";
        if ("USER_FOLLOW".equals(type)) return "FOLLOW";
        if ("POST_LIKE".equals(type)) return "LIKE";
        if (type.startsWith("POST_") || "COMMENT_REPLY".equals(type) || "COMMENT_LIKE".equals(type) || "FORUM".equals(type)) return "SOCIAL";
        if (data.containsKey("ticketId") || data.containsKey("feedbackId")) return "SUPPORT";
        if ("MEAL".equals(data.get("target")) || "MEAL".equals(data.get("targetType"))) return "MEAL";
        if ("SYSTEM".equals(type)) {
            if (data.containsKey("securityKind")) return "SECURITY";
            return "1".equals(data.get("moderation")) ? "MODERATION" : "SYSTEM";
        }
        return "ANNOUNCEMENT";
    }

    public static PushMessage normalizeMedia(PushMessage message, String base) {
        var data = new LinkedHashMap<>(message.data());
        for (String key : java.util.List.of("imageUrl", "senderAvatarUrl")) {
            String url = RichChatPayload.mediaUrl(base, data.get(key));
            if (url == null) data.remove(key); else data.put(key, url);
        }
        return new PushMessage(message.title(), message.body(), Map.copyOf(data), message.collapseKey(),
                message.threadId(), message.channelId(), message.category(), message.badge(), message.highPriority(), message.ttlSeconds());
    }

    public static PushMessage enrich(PushMessage message, String base, String locale) {
        return enrich(message, base, locale, null);
    }

    /**
     * Genel yayin (haber, herkese acik anket): alici bazli yuk yok. `recipientId` yerine `broadcast=1` konur; Android
     * oturum acik herhangi bir hesapta cizer (icerik tum kullanicilara ayni ve herkese aciktir).
     */
    public static PushMessage enrichBroadcast(PushMessage message, String base, String locale) {
        var seed = new LinkedHashMap<>(message.data());
        seed.put("broadcast", "1");
        PushMessage tagged = new PushMessage(message.title(), message.body(), Map.copyOf(seed), message.collapseKey(),
                message.threadId(), message.channelId(), message.category(), message.badge(), message.highPriority(),
                message.ttlSeconds());
        return enrich(tagged, base, locale, null);
    }

    public static PushMessage enrich(PushMessage message, String base, String locale, Long recipientId) {
        var data = new LinkedHashMap<>(message.data());
        if (recipientId != null) data.put("recipientId", recipientId.toString());
        data.put("richNotification", "1");
        data.put("title", message.title() == null ? "" : message.title());
        data.put("body", message.body() == null ? "" : message.body());
        data.put("style", style(data));
        data.put("locale", locale == null ? "tr" : locale);
        for (String key : java.util.List.of("senderAvatarUrl", "imageUrl")) {
            String url = RichChatPayload.mediaUrl(base, data.get(key));
            if (url == null) data.remove(key); else data.put(key, url);
        }
        // Keep title/body and renderer markers even when optional media metadata exceeds the FCM limit.
        while (PushPayload.sizeOf(data) > PushPayload.MAX_BYTES) {
            if (data.remove("imageUrl") != null || data.remove("senderAvatarUrl") != null) continue;
            String body = data.get("body");
            if (body.length() > 64) { data.put("body", body.substring(0, body.length() / 2)); continue; }
            return message; // fail back to standard FCM; never send an oversized data-only alert
        }
        return new PushMessage(message.title(), message.body(), Map.copyOf(data), message.collapseKey(),
                message.threadId(), message.channelId(), "BU_" + data.get("style"), message.badge(),
                message.highPriority(), message.ttlSeconds());
    }
}
