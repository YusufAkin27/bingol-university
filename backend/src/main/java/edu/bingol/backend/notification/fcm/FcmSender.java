package edu.bingol.backend.notification.fcm;

import java.util.Collection;
import java.util.List;
import java.util.Map;

/** Push gonderici soyutlamasi. Gercek uygulama FirebaseFcmSender; kimlik bilgisi yoksa LoggingFcmSender. */
public interface FcmSender {

    /** @return artik gecerli olmayan (silinmesi gereken) token'lar */
    List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data);

    /**
     * Gruplanabilir bildirim: collapseKey ayni olan bekleyen bildirimlerin yerine gecer (FCM collapse_key + tag).
     * Varsayilan uygulama anahtari yok sayar.
     */
    default List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data,
                              String collapseKey) {
        return send(tokens, title, body, data);
    }

    /**
     * Zengin gonderim (rozet, kanal, thread-id...). Dondurulen sonuc gecersiz token'lari ve yeniden denenebilir
     * (gecici hatali) token'lari ayirir. Varsayilan: eski imzaya duser, gecici hata bildirmez.
     */
    default SendResult deliver(Collection<String> tokens, PushMessage m) {
        return new SendResult(send(tokens, m.title(), m.body(), m.data(), m.collapseKey()), List.of());
    }

    /** false ise gonderim yapilmaz (kimlik bilgisi yok); uygulama ici bildirim kutusu yine yazilir. */
    default boolean enabled() {
        return true;
    }
}
