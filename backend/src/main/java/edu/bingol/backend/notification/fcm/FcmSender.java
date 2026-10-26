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
}
