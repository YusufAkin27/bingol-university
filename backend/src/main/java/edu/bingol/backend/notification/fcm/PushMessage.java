package edu.bingol.backend.notification.fcm;

import java.util.Map;

/**
 * Tek bildirimin platformdan bagimsiz tanimi.
 *
 * @param collapseKey  ayni anahtarli bekleyen bildirimin yerine gecer (Android collapse_key+tag, iOS apns-collapse-id)
 * @param threadId     iOS thread-id / Android grup etiketi (sohbet, kulup gruplamasi)
 * @param channelId    Android bildirim kanali (chat, announcement, event)
 * @param category     iOS kategorisi (eyleme donusen bildirim turu)
 * @param badge        iOS rozet sayisi (okunmamis); null ise rozet degismez
 * @param highPriority mesaj gibi anlik bildirimler (Android HIGH, APNs 10)
 */
public record PushMessage(String title, String body, Map<String, String> data, String collapseKey, String threadId,
                          String channelId, String category, Integer badge, boolean highPriority) {

    /** Eski, yalnizca metin+veri gonderimi icin. */
    public static PushMessage simple(String title, String body, Map<String, String> data, String collapseKey) {
        return new PushMessage(title, body, data, collapseKey, null, null, null, null, false);
    }
}
