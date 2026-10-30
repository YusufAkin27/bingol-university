package edu.bingol.backend.notification.fcm;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** FCM kimlik bilgisi yokken kullanilir: push gondermez; token ve metin sizdirmadan yalnizca adet loglar. */
public class LoggingFcmSender implements FcmSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingFcmSender.class);

    /** Neden kapali: NO_CREDENTIALS (kimlik girilmemis) ya da INIT_FAILED:<hata sinifi> (kimlik var ama baslatilamadi). */
    private final String reason;

    public LoggingFcmSender() {
        this("NO_CREDENTIALS");
    }

    public LoggingFcmSender(String reason) {
        this.reason = reason;
    }

    /** Yonetici durum ucu icin: sessiz kalmasin diye kapali olma nedeni (sir icermez). */
    @Override
    public FcmCheck check(boolean dryRun) {
        return new FcmCheck(false, false, null, reason);
    }

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
