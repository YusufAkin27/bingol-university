package edu.bingol.backend.support.ticket;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Herkese acik destek formu icin sunucu imzali, zaman damgali form jetonu (T-062, A16-12). Istemcinin bildirdigi
 * {@code elapsedMs} ve bal kabagi tek basina guvenilmezdi (bot ikisini de uydurur); jeton formu ACARKEN sunucudan
 * alinir ve gonderimde en az {@code app.support.min-fill-seconds} gecmis, en cok 2 saat eski olmalidir.
 *
 * <p>Bicim: {@code v1.<verilmeMs>.<nonce>.<hmac-sha256>} (HMAC anahtari: {@code app.support.form-token-secret},
 * bos ise JWT sirrindan turetilir). Jeton gizli veri tasimaz; yalniz imza ve zaman.
 */
@Component
public class SupportFormToken {

    /** Dogrulama sonucu. */
    public enum Result { OK, TOO_FAST, INVALID }

    static final long MAX_AGE_MS = 2 * 60 * 60 * 1000L;

    private final byte[] key;
    private final Clock clock;
    private final long minFillMs;
    private final boolean required;
    private final SecureRandom random = new SecureRandom();

    @Autowired
    public SupportFormToken(@Value("${app.support.form-token-secret:}") String secret,
                            @Value("${jwt.secret:dev-only}") String jwtSecret,
                            @Value("${app.support.min-fill-seconds:3}") int minFillSeconds,
                            @Value("${app.support.form-token-required:true}") boolean required) {
        this(secret, jwtSecret, minFillSeconds, required, Clock.systemUTC());
    }

    SupportFormToken(String secret, String jwtSecret, int minFillSeconds, boolean required, Clock clock) {
        String base = secret == null || secret.isBlank() ? "support-form:" + jwtSecret : secret;
        this.key = base.getBytes(StandardCharsets.UTF_8);
        this.minFillMs = Math.max(0, minFillSeconds) * 1000L;
        this.required = required;
        this.clock = clock;
    }

    /** Jeton zorunlu mu (kapaliyken yalniz eski elapsedMs denetimi). */
    public boolean required() {
        return required;
    }

    public long minFillMs() {
        return minFillMs;
    }

    public String issue() {
        byte[] n = new byte[8];
        random.nextBytes(n);
        String body = "v1." + clock.millis() + "." + HexFormat.of().formatHex(n);
        return body + "." + sign(body);
    }

    public Result verify(String token) {
        if (token == null || token.length() > 200) {
            return Result.INVALID;
        }
        String[] p = token.split("\\.");
        if (p.length != 4 || !p[0].equals("v1")) {
            return Result.INVALID;
        }
        String body = p[0] + "." + p[1] + "." + p[2];
        if (!MessageDigest.isEqual(sign(body).getBytes(StandardCharsets.UTF_8), p[3].getBytes(StandardCharsets.UTF_8))) {
            return Result.INVALID;
        }
        long issued;
        try {
            issued = Long.parseLong(p[1]);
        } catch (NumberFormatException e) {
            return Result.INVALID;
        }
        long age = clock.millis() - issued;
        if (age < 0 || age > MAX_AGE_MS) {
            return Result.INVALID;
        }
        return age < minFillMs ? Result.TOO_FAST : Result.OK;
    }

    /** Jetonun tek-kullanim (az-kullanim) sayaci icin nonce; gecerli jeton varsayilir. */
    static String nonceOf(String token) {
        String[] p = token.split("\\.");
        return p.length == 4 ? p[2] : "";
    }

    private String sign(String body) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(body.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
