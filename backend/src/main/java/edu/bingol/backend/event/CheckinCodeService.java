package edu.bingol.backend.event;

import edu.bingol.backend.config.JwtProperties;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Kisa omurlu QR yoklama kodu: "{eventId}.{pencere}.{HMAC}". Pencere 30 sn'lik zaman dilimidir; dogrulama
 * guncel ve bir onceki pencereyi kabul eder (kod 30-60 sn gecerli), boylece ekran goruntusu paylasimi hizla bosa cikar.
 * Anahtar jwt.secret'tan turetilir (alan ayrimi icin sabit etiketle), kodda sir yoktur.
 */
@Component
public class CheckinCodeService {

    static final long STEP_SECONDS = 30;
    /** Kodun en uzun gecerlilik suresi (sn): guncel + onceki pencere. */
    static final int MAX_VALID_SECONDS = (int) (STEP_SECONDS * 2);

    private final byte[] key;

    public CheckinCodeService(JwtProperties jwt) {
        this.key = hmac(jwt.secret().getBytes(StandardCharsets.UTF_8), "bingol-checkin-v1");
    }

    public String generate(long eventId, Instant now) {
        long w = window(now);
        return eventId + "." + w + "." + mac(eventId, w);
    }

    /** Kodun gecerli son an'i (uretildigi pencereden sonraki pencerenin sonu). */
    public Instant expiresAt(Instant now) {
        return Instant.ofEpochSecond((window(now) + 2) * STEP_SECONDS);
    }

    public boolean verify(long eventId, String code, Instant now) {
        if (code == null) {
            return false;
        }
        String[] p = code.trim().split("\\.", -1);
        if (p.length != 3) {
            return false;
        }
        long id;
        long w;
        try {
            id = Long.parseLong(p[0]);
            w = Long.parseLong(p[1]);
        } catch (NumberFormatException e) {
            return false;
        }
        long current = window(now);
        if (id != eventId || w > current || w < current - 1) {
            return false;
        }
        return MessageDigest.isEqual(mac(id, w).getBytes(StandardCharsets.UTF_8), p[2].getBytes(StandardCharsets.UTF_8));
    }

    private static long window(Instant t) {
        return t.getEpochSecond() / STEP_SECONDS;
    }

    private String mac(long eventId, long window) {
        byte[] full = hmac(key, eventId + "." + window);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(Arrays.copyOf(full, 16));
    }

    private static byte[] hmac(byte[] key, String data) {
        try {
            Mac m = Mac.getInstance("HmacSHA256");
            m.init(new SecretKeySpec(key, "HmacSHA256"));
            return m.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
