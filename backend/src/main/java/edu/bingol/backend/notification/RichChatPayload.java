package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.PushMessage;
import java.net.URI;
import java.util.HashMap;

/** Yeni Android istemcisi icin veri mesaji; eski cihazlar standart FCM bildirimini korur. */
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
        var data = new HashMap<String, String>(m.data() == null ? java.util.Map.of() : m.data());
        data.put("richChat", "1");
        data.put("title", m.title() == null ? "" : m.title());
        data.put("body", m.body() == null ? "" : m.body());
        for (String key : java.util.List.of("senderAvatarUrl", "imageUrl")) {
            String value = mediaUrl(base, data.get(key));
            if (value == null) data.remove(key); else data.put(key, value);
        }
        return new PushMessage(m.title(), m.body(), java.util.Map.copyOf(data), m.collapseKey(), m.threadId(),
                m.channelId(), m.category(), m.badge(), m.highPriority(), m.ttlSeconds());
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
