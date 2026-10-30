package edu.bingol.backend.notification.fcm;

import java.util.Map;

/**
 * Tek bildirimin platformdan bagimsiz tanimi.
 *
 * @param collapseKey  ayni anahtarli bildirimin yerine gecer (Android `tag`, iOS `apns-collapse-id`). FCM `collapse_key`
 *                     GONDERILMEZ: bu anahtar cevrimdisi cihazda en fazla 4 farkli anahtara izin verir, fazlasi
 *                     davranisi belirsiz yapar ve sohbet mesajlarini sessizce dusurebilir.
 * @param threadId     iOS thread-id / Android grup etiketi (sohbet, kulup gruplamasi)
 * @param channelId    Android bildirim kanali (chat, announcement, event, poll, social)
 * @param category     iOS kategorisi (eyleme donusen bildirim turu)
 * @param badge        iOS rozet sayisi (okunmamis); null ise rozet degismez
 * @param highPriority mesaj gibi anlik bildirimler (Android HIGH, APNs 10)
 * @param ttlSeconds   cihaz cevrimdisiyken FCM/APNs'in bildirimi tutma suresi (sn); null ise platform varsayilani (4 hafta).
 *                     Eski kuyruk satirlarinda alan yoktur (null).
 */
public record PushMessage(String title, String body, Map<String, String> data, String collapseKey, String threadId,
                          String channelId, String category, Integer badge, boolean highPriority, Integer ttlSeconds) {

    /** Eski 9 alanli kurucu (ttl yok). */
    public PushMessage(String title, String body, Map<String, String> data, String collapseKey, String threadId,
                       String channelId, String category, Integer badge, boolean highPriority) {
        this(title, body, data, collapseKey, threadId, channelId, category, badge, highPriority, null);
    }

    /** Eski, yalnizca metin+veri gonderimi icin. */
    public static PushMessage simple(String title, String body, Map<String, String> data, String collapseKey) {
        return new PushMessage(title, body, data, collapseKey, null, null, null, null, false);
    }
}
