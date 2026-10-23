package edu.bingol.backend.notification.fcm;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.stereotype.Component;

/** FCM kimlik bilgisi (app.fcm.credentials-file) yokken kullanilir: push gondermez, yalnizca log'lar. */
@Component
@ConditionalOnExpression("'${app.fcm.credentials-file:}'.isEmpty()")
public class LoggingFcmSender implements FcmSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingFcmSender.class);

    @Override
    public List<String> send(Collection<String> tokens, String title, String body, Map<String, String> data) {
        log.info("[FCM kapali] {} cihaza gonderilmedi: {}", tokens.size(), title);
        return List.of();
    }
}
