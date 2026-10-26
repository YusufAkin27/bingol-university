package edu.bingol.backend.media;

import edu.bingol.backend.config.MediaProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Ozel medya icin kisa omurlu imzali URL: {@code /files/p/{kova}/{anahtar}?exp=<epoch sn>&sig=<hmac>}.
 * URL'yi YALNIZ yetkili kullaniciya uretin (ornek: konusma katilimcisi); <img> etiketi Bearer basligi gonderemez.
 */
@Component
public class MediaUrlSigner {

    static final Duration MAX_TTL = Duration.ofHours(1);

    private final byte[] key;

    public MediaUrlSigner(MediaProperties props, @Value("${jwt.secret}") String jwtSecret) {
        String s = props.signingSecret();
        // Ayri anahtar verilmediyse JWT sirrindan alan-ayrimli tureterek kullan
        this.key = (s == null || s.isBlank() ? "media-url:" + jwtSecret : s).getBytes(StandardCharsets.UTF_8);
    }

    public String sign(String bucket, String key, Duration ttl) {
        Duration t = ttl.compareTo(MAX_TTL) > 0 ? MAX_TTL : ttl;
        long exp = Instant.now().plus(t).getEpochSecond();
        return "/files/p/" + bucket + "/" + key + "?exp=" + exp + "&sig=" + mac(bucket, key, exp);
    }

    public boolean verify(String bucket, String key, long exp, String sig) {
        if (sig == null || exp < Instant.now().getEpochSecond()
                || exp > Instant.now().plus(MAX_TTL).getEpochSecond() + 60) {
            return false;
        }
        return MessageDigest.isEqual(mac(bucket, key, exp).getBytes(StandardCharsets.UTF_8),
                sig.getBytes(StandardCharsets.UTF_8));
    }

    private String mac(String bucket, String name, long exp) {
        try {
            Mac m = Mac.getInstance("HmacSHA256");
            m.init(new SecretKeySpec(key, "HmacSHA256"));
            return HexFormat.of().formatHex(
                    m.doFinal((bucket + "/" + name + "|" + exp).getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
