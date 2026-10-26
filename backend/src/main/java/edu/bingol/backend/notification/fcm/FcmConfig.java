package edu.bingol.backend.notification.fcm;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * FcmSender secimi. Kimlik bilgisi sirayla: FCM_CREDENTIALS_JSON (ham JSON ya da base64), FCM_CREDENTIALS_FILE.
 * Hicbiri yoksa ya da gecersizse sistem hata vermeden devre disi (LoggingFcmSender) calisir.
 */
@Configuration
@Profile("!test") // testlerde FakeFcmSender kullanilir
public class FcmConfig {

    private static final Logger log = LoggerFactory.getLogger(FcmConfig.class);

    @Bean
    public FcmSender fcmSender(@Value("${app.fcm.credentials-json:${FCM_CREDENTIALS_JSON:}}") String json,
                               @Value("${app.fcm.credentials-file:}") String file) {
        try (InputStream in = open(json, file)) {
            if (in == null) {
                log.info("FCM kimlik bilgisi yok: push devre disi, uygulama ici bildirimler calisir");
                return new LoggingFcmSender();
            }
            return new FirebaseFcmSender(in);
        } catch (IOException | RuntimeException e) {
            // Kimlik icerigi log'a girmesin: yalnizca hata turu yazilir.
            log.warn("FCM baslatilamadi ({}): push devre disi", e.getClass().getSimpleName());
            return new LoggingFcmSender();
        }
    }

    /** @return kimlik akisi; hicbir kaynak yoksa null */
    static InputStream open(String json, String file) throws IOException {
        if (json != null && !json.isBlank()) {
            String t = json.trim();
            byte[] raw = t.startsWith("{") ? t.getBytes(StandardCharsets.UTF_8) : Base64.getDecoder().decode(t);
            return new ByteArrayInputStream(raw);
        }
        if (file != null && !file.isBlank()) {
            return new FileInputStream(file);
        }
        return null;
    }
}
