package edu.bingol.backend.notification.fcm;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** FCM kimlik bilgisi yokken kullanilir: push gondermez; token ve metin sizdirmadan yalnizca adet loglar. */
public class LoggingFcmSender implements FcmSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingFcmSender.class);

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data) {
        log.debug("[FCM kapali] {} cihaza gonderilmedi", tokens.size());
        return List.of();
    }

    @Override
    public boolean enabled() {
        return false;
    }
}
