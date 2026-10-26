package edu.bingol.backend.notification;

import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Push `data` yuku sozlesmesi (mobil istemci bunu okur):
 * <ul>
 *   <li>`type`: ana tur (NEWS, ANNOUNCEMENT, EVENT, MESSAGE, COMMUNITY, SYSTEM)</li>
 *   <li>`subtype`: varsa alt tur</li>
 *   <li>`target` + `value`: yonlendirme (NEWS, EVENT, COMMUNITY, POST, CONVERSATION, TICKET, FEEDBACK, URL; value = kimlik/URL)</li>
 *   <li>`count`: gruplanmis bildirimde birlesen adet (&gt;1 ise)</li>
 *   <li>diger anahtarlar (newsId, conversationId...) geriye uyumluluk icin aynen korunur</li>
 * </ul>
 * FCM data toplam siniri 4096 bayttir; asilirsa sozlesme disi anahtarlar atilir.
 */
public final class PushPayload {

    public static final int MAX_BYTES = 4096;
    /** Oncelik sirasiyla: (veri anahtari, target). */
    private static final List<String[]> TARGETS = List.of(
            new String[] {"postId", "POST"}, new String[] {"conversationId", "CONVERSATION"},
            new String[] {"eventId", "EVENT"}, new String[] {"communityId", "COMMUNITY"},
            new String[] {"newsId", "NEWS"}, new String[] {"ticketId", "TICKET"},
            new String[] {"feedbackId", "FEEDBACK"});
    private static final List<String> CONTRACT = List.of("type", "subtype", "target", "value", "count");

    private PushPayload() {}

    public static Map<String, String> build(NotificationType type, NotificationSubtype subtype,
                                            Map<String, String> data, int groupCount) {
        Map<String, String> out = new LinkedHashMap<>();
        if (data != null) {
            data.forEach((k, v) -> {
                // FCM ayrilmis anahtarlari reddeder; null deger de olmaz.
                if (k != null && v != null && !k.startsWith("google") && !k.startsWith("gcm") && !k.equals("from")) {
                    out.put(k, v);
                }
            });
        }
        out.put("type", type.name());
        if (subtype != null) {
            out.put("subtype", subtype.name());
        }
        if (!out.containsKey("target")) {
            for (String[] t : TARGETS) {
                String v = out.get(t[0]);
                if (v != null) {
                    out.put("target", t[1]);
                    out.put("value", v);
                    break;
                }
            }
        }
        if (groupCount > 1) {
            out.put("count", String.valueOf(groupCount));
        }
        return fit(out);
    }

    static int sizeOf(Map<String, String> m) {
        int n = 0;
        for (Map.Entry<String, String> e : m.entrySet()) {
            n += e.getKey().getBytes(StandardCharsets.UTF_8).length + e.getValue().getBytes(StandardCharsets.UTF_8).length;
        }
        return n;
    }

    /** Sinira sigana dek sozlesme disi anahtarlari (en buyukten) atar; sozlesme anahtarlari korunur. */
    static Map<String, String> fit(Map<String, String> m) {
        Map<String, String> out = new LinkedHashMap<>(m);
        while (sizeOf(out) > MAX_BYTES) {
            String biggest = null;
            int size = -1;
            for (Map.Entry<String, String> e : out.entrySet()) {
                int s = e.getValue().getBytes(StandardCharsets.UTF_8).length;
                if (!CONTRACT.contains(e.getKey()) && s > size) {
                    biggest = e.getKey();
                    size = s;
                }
            }
            if (biggest == null) {
                // yalnizca sozlesme anahtarlari kaldi: value'yu kirp (URL cok uzunsa)
                String v = out.get("value");
                if (v == null || v.length() < 16) {
                    break;
                }
                out.put("value", v.substring(0, v.length() / 2));
            } else {
                out.remove(biggest);
            }
        }
        return out;
    }
}
