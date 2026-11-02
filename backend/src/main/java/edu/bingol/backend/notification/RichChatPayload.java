package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.net.URI;
import java.util.HashMap;

/**
 * Yeni Android istemcisi (>= 2.0.8) icin veri mesaji; eski cihazlar standart FCM bildirimini korur. Ad sohbetten kalma:
 * zengin yol artik TUM kanallar icindir (sohbet, etkinlik, duyuru, anket, sosyal, akademik, guvenlik); karti cizen
 * istemci kodu yayinlanana dek `app.push.rich-chat-enabled` KAPALI kalir.
 */
public final class RichChatPayload {
    private RichChatPayload() {}

    public static boolean supports(Device d) {
        if (d == null || !"ANDROID".equalsIgnoreCase(d.getPlatform()) || d.getAppVersion() == null) return false;
        try {
            String[] v = d.getAppVersion().split("\\.");
            int major = Integer.parseInt(v[0]);
            int minor = v.length > 1 ? Integer.parseInt(v[1]) : 0;
            int patch = v.length > 2 ? Integer.parseInt(v[2].replaceFirst("[^0-9].*$", "")) : 0;
            return major > 2 || (major == 2 && (minor > 0 || (minor == 0 && patch >= 8)));
        } catch (RuntimeException e) { return false; }
    }

    public static Long previewAttachmentId(java.util.List<edu.bingol.backend.messaging.media.AttachmentView> attachments) {
        if (attachments == null) return null;
        return attachments.stream().filter(a -> a != null && !a.viewOnce() && !a.removed()
                && "IMAGE".equalsIgnoreCase(a.kind()) && a.thumbUrl() != null)
                .map(edu.bingol.backend.messaging.media.AttachmentView::id).findFirst().orElse(null);
    }

    public static boolean isRich(PushMessage m) {
        return m.data() != null && "1".equals(m.data().get("richChat"));
    }

    public static PushMessage enrich(PushMessage m, String base) {
        var data = new HashMap<String, String>(normalizeMedia(m, base).data());
        data.put("richChat", "1");
        data.put("title", m.title() == null ? "" : m.title());
        data.put("body", m.body() == null ? "" : m.body());
        if (m.channelId() != null) {
            data.putIfAbsent("channelId", m.channelId());
        }
        // `tag`: ayni etiketli bildirim cihazda yenisiyle degisir (cokme anahtari). Uretici verdiyse korunur
        // (collapseKey), yoksa kanala gore hedeften turetilir; turetilemezse konmaz (istemci kimlik uretir).
        if (!data.containsKey("tag") && m.collapseKey() != null) {
            data.put("tag", m.collapseKey());
        }
        if (!data.containsKey("tag")) {
            String tag = defaultTag(data);
            if (tag != null) data.put("tag", tag);
        }
        return new PushMessage(m.title(), m.body(), java.util.Map.copyOf(data), m.collapseKey(), m.threadId(),
                m.channelId(), m.category(), m.badge(), m.highPriority(), m.ttlSeconds());
    }

    /**
     * Gorsel anahtarlarini mutlak https adrese cevirir, gecersizleri (yabanci alan adi, http) dusurur; zengin/eski
     * ayrimi yapmaz (iOS `fcm_options.image` de mutlak adres ister). Avatar yalniz uygulamanin kendi alan adindan;
     * `imageUrl` ayrica universite alan adindan (haber kucuk resmi `*.bingol.edu.tr`) olabilir.
     */
    public static PushMessage normalizeMedia(PushMessage m, String base) {
        if (m.data() == null || !(m.data().containsKey("senderAvatarUrl") || m.data().containsKey("imageUrl"))) {
            return m;
        }
        var data = new HashMap<String, String>(m.data());
        String avatar = mediaUrl(base, data.get("senderAvatarUrl"));
        if (avatar == null) data.remove("senderAvatarUrl"); else data.put("senderAvatarUrl", avatar);
        String image = imageUrl(base, data.get("imageUrl"));
        if (image == null) {
            data.remove("imageUrl");
            data.remove("imageStyle"); // gorselsiz kartta stil anlamsiz
        } else {
            data.put("imageUrl", image);
        }
        return new PushMessage(m.title(), m.body(), java.util.Map.copyOf(data), m.collapseKey(), m.threadId(),
                m.channelId(), m.category(), m.badge(), m.highPriority(), m.ttlSeconds());
    }

    /** Kanal/karta gore cokme etiketi (hedeften); turetilemezse null. */
    static String defaultTag(java.util.Map<String, String> d) {
        String card = d.getOrDefault("card", "");
        String conv = d.get("conversationId");
        if (conv != null) return "conv:" + conv;
        if (card.startsWith("SECURITY_")) return "security:" + card;
        if (card.startsWith("EVENT_") && d.get("eventId") != null) return "event:" + d.get("eventId");
        if (card.startsWith("POLL_") && d.get("pollId") != null) return "poll:" + d.get("pollId");
        if (d.get("newsId") != null) return "news:" + d.get("newsId");
        if (d.get("ticketId") != null) return "ticket:" + d.get("ticketId");
        if (d.get("unitNewsId") != null) return "unit:" + d.get("unitNewsId");
        if ("MENU_TODAY".equals(card) && d.get("menuDate") != null) return "menu:" + d.get("menuDate");
        String tt = d.get("targetType");
        String tid = d.get("targetId");
        if (tt != null && tid != null && !tid.isBlank()) return tt.toLowerCase(java.util.Locale.ROOT) + ":" + tid;
        return null;
    }

    /** `imageUrl`: uygulama alan adi ya da https `bingol.edu.tr` (alt alanlar dahil). */
    public static String imageUrl(String base, String raw) {
        String own = mediaUrl(base, raw);
        if (own != null) return own;
        if (raw == null || raw.isBlank()) return null;
        try {
            URI url = URI.create(raw.trim());
            String host = url.getHost();
            return "https".equalsIgnoreCase(url.getScheme()) && host != null && url.getUserInfo() == null
                    && url.getFragment() == null && (host.equalsIgnoreCase("bingol.edu.tr")
                    || host.toLowerCase(java.util.Locale.ROOT).endsWith(".bingol.edu.tr"))
                    ? url.toASCIIString() : null;
        } catch (IllegalArgumentException e) { return null; }
    }

    public static String mediaUrl(String base, String raw) {
        if (base == null || base.isBlank() || raw == null || raw.isBlank()) return null;
        try {
            URI origin = URI.create(base);
            URI url = origin.resolve(raw);
            return "https".equalsIgnoreCase(origin.getScheme()) && "https".equalsIgnoreCase(url.getScheme())
                    && origin.getHost() != null && origin.getHost().equalsIgnoreCase(url.getHost())
                    && origin.getPort() == url.getPort() && url.getUserInfo() == null && url.getFragment() == null
                    ? url.toASCIIString() : null;
        } catch (IllegalArgumentException e) { return null; }
    }
}
