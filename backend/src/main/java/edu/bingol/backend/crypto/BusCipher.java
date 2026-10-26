package edu.bingol.backend.crypto;

import edu.bingol.backend.crypto.CryptoException.Reason;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;
import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Redis pub/sub (sunucular arasi olay) yuku sifreleme. Cerceve: "v1.&lt;anahtarId&gt;.&lt;base64url(nonce || ct)&gt;".
 * Anahtar = HMAC-SHA256(ana anahtar[anahtarId], "bu-bus-v1") (konusma DEK'i degil: olay konusmaya ozel olmayabilir).
 * Tum sunucular ayni ana anahtar listesini tasimalidir; cerceve anahtar kimligini icerdigi icin rotasyonda eski
 * kimlikli cerceveler de acilir.
 */
@Component
public class BusCipher {

    private static final String VERSION = "v1";
    private static final byte[] LABEL = "bu-bus-v1".getBytes(StandardCharsets.US_ASCII);

    private final KeyProvider keys;
    private final CryptoService crypto;
    private final Map<String, SecretKey> derived = new ConcurrentHashMap<>();

    public BusCipher(KeyProvider keys, CryptoService crypto) {
        this.keys = keys;
        this.crypto = crypto;
    }

    public String seal(String plain) {
        String kid = keys.activeKeyId();
        byte[] nonce = crypto.newNonce();
        byte[] ct = crypto.encrypt(busKey(kid), nonce, aad(kid), plain.getBytes(StandardCharsets.UTF_8));
        byte[] body = ByteBuffer.allocate(nonce.length + ct.length).put(nonce).put(ct).array();
        return VERSION + "." + kid + "." + Base64.getUrlEncoder().withoutPadding().encodeToString(body);
    }

    /** Bozuk/kurcalanmis/bilinmeyen anahtarli cerceve icin CryptoException firlatir (icerik loglanmaz). */
    public String open(String frame) {
        String[] p = frame == null ? new String[0] : frame.split("\\.", 3);
        if (p.length != 3 || !VERSION.equals(p[0])) {
            throw new CryptoException(Reason.MALFORMED, "Olay cercevesi gecersiz");
        }
        byte[] body;
        try {
            body = Base64.getUrlDecoder().decode(p[2]);
        } catch (IllegalArgumentException e) {
            throw new CryptoException(Reason.MALFORMED, "Olay cercevesi gecersiz");
        }
        if (body.length <= CryptoService.NONCE_BYTES) {
            throw new CryptoException(Reason.MALFORMED, "Olay cercevesi gecersiz");
        }
        byte[] nonce = java.util.Arrays.copyOfRange(body, 0, CryptoService.NONCE_BYTES);
        byte[] ct = java.util.Arrays.copyOfRange(body, CryptoService.NONCE_BYTES, body.length);
        return new String(crypto.open(busKey(p[1]), aad(p[1]), nonce, ct), StandardCharsets.UTF_8);
    }

    private SecretKey busKey(String kid) {
        SecretKey cached = derived.get(kid);
        if (cached != null) {
            return cached;
        }
        SecretKey master = keys.key(kid); // bilinmiyorsa KEY_UNAVAILABLE
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(master.getEncoded(), "HmacSHA256"));
            SecretKey k = new SecretKeySpec(mac.doFinal(LABEL), "AES");
            derived.put(kid, k);
            return k;
        } catch (GeneralSecurityException e) {
            throw new CryptoException(Reason.CONFIG, "Olay anahtari turetilemedi", e);
        }
    }

    private static byte[] aad(String kid) {
        return Aad.of("bus", 0, kid.getBytes(StandardCharsets.US_ASCII));
    }
}
