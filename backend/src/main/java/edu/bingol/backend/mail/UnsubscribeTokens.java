package edu.bingol.backend.mail;

import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Abonelikten cikma jetonu: tek amacli (alan ayirici "mail-unsub"), sureli, HMAC-SHA256 imzali.
 * Icerik: adresin SHA-256 ozeti + son kullanma (adresin kendisi URL'ye girmez). Sunucuda durum tutulmaz;
 * kullanici varligi hakkinda bilgi sizmaz (gecerli imzali her jeton ayni sekilde islenir).
 * Format: base64url("v1.hash.expEpochSec") + "." + base64url(mac).
 */
@Component
public class UnsubscribeTokens {

    private static final String PURPOSE = "mail-unsub|";

    private final MailProperties props;
    private final byte[] key;

    public UnsubscribeTokens(MailProperties props, @Value("${jwt.secret:}") String jwtSecret) {
        this.props = props;
        String k = props.unsubscribeKey() != null && !props.unsubscribeKey().isBlank()
                ? props.unsubscribeKey() : "mail-unsub-v1:" + jwtSecret;
        this.key = k.getBytes(StandardCharsets.UTF_8);
    }

    public String create(String email, Instant now) {
        long exp = now.plus(Duration.ofDays(Math.max(1, props.unsubscribeTtlDays()))).getEpochSecond();
        String payload = "v1." + MailSuppressionService.hash(email) + "." + exp;
        return b64(payload.getBytes(StandardCharsets.UTF_8)) + "." + b64(mac(PURPOSE + payload));
    }

    /** Gecerliyse adres ozetini doner; imza/sure/bicim hatasinda bos. */
    public Optional<String> verify(String token, Instant now) {
        try {
            if (token == null || token.length() > 400) {
                return Optional.empty();
            }
            int dot = token.indexOf('.');
            if (dot < 1 || dot != token.lastIndexOf('.')) {
                return Optional.empty();
            }
            byte[] payloadBytes = Base64.getUrlDecoder().decode(token.substring(0, dot));
            byte[] given = Base64.getUrlDecoder().decode(token.substring(dot + 1));
            String payload = new String(payloadBytes, StandardCharsets.UTF_8);
            if (!MessageDigest.isEqual(given, mac(PURPOSE + payload))) {
                return Optional.empty();
            }
            String[] parts = payload.split("\\.");
            if (parts.length != 3 || !"v1".equals(parts[0]) || !parts[1].matches("[0-9a-f]{64}")) {
                return Optional.empty();
            }
            if (Long.parseLong(parts[2]) < now.getEpochSecond()) {
                return Optional.empty();
            }
            return Optional.of(parts[1]);
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    /** Postadaki baglanti; kok adres tanimsizsa null (duyuru gonderilmez). */
    public String url(String email, Lang lang, Instant now) {
        String base = props.unsubscribeBaseUrl();
        if (base == null || base.isBlank()) {
            return null;
        }
        return base.trim().replaceAll("/+$", "") + "/api/public/mail/unsubscribe?token=" + create(email, now)
                + "&lang=" + lang.code();
    }

    private byte[] mac(String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException("HMAC kullanilamiyor", e);
        }
    }

    private static String b64(byte[] b) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }
}
