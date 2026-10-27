package edu.bingol.backend.accessban;

import edu.bingol.backend.common.ClientIp;
import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.Locale;
import java.util.regex.Pattern;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Istekten {@link ClientContext} uretir ve cihaz kimligini HMAC-SHA256 ile ozetler. Anahtar:
 * `app.security.device-hmac-key` (DEVICE_HMAC_KEY); bos ise JWT sirrindan turetilir. Ham cihaz kimligi yalnizca bu
 * sinifin yerel degiskenlerinde yasar; saklanmaz ve log'lanmaz.
 */
@Component
public class ClientContexts {

    public static final String DEVICE_HEADER = "X-Device-Id";
    public static final String PLATFORM_HEADER = "X-Device-Platform";
    public static final String VERSION_HEADER = "X-App-Version";

    private static final Pattern RAW_DEVICE = Pattern.compile("[A-Za-z0-9._:\\-]{8,128}");
    private static final Pattern VERSION = Pattern.compile("[A-Za-z0-9._+\\-]{1,32}");

    private final ClientIp clientIp;
    private final byte[] key;

    public ClientContexts(ClientIp clientIp,
                          @Value("${app.security.device-hmac-key:}") String hmacKey,
                          @Value("${jwt.secret:}") String jwtSecret) {
        this.clientIp = clientIp;
        this.key = (hmacKey != null && !hmacKey.isBlank() ? hmacKey : "device-hmac-v1:" + jwtSecret)
                .getBytes(StandardCharsets.UTF_8);
    }

    /** Istek basina bir kez hesaplanir (istek niteligine yazilir). */
    public ClientContext of(HttpServletRequest req) {
        Object cached = req.getAttribute(ClientContext.REQUEST_ATTR);
        if (cached instanceof ClientContext c) {
            return c;
        }
        ClientContext c = build(clientIp.of(req), req.getHeader(DEVICE_HEADER), req.getHeader(PLATFORM_HEADER),
                req.getHeader(VERSION_HEADER));
        req.setAttribute(ClientContext.REQUEST_ATTR, c);
        return c;
    }

    public ClientContext build(String ip, String rawDeviceId, String platform, String appVersion) {
        String raw = rawDeviceId == null ? null : rawDeviceId.trim();
        String hash = raw != null && RAW_DEVICE.matcher(raw).matches() ? hash(raw) : null;
        return new ClientContext(ip, hash, platform(platform),
                appVersion != null && VERSION.matcher(appVersion.trim()).matches() ? appVersion.trim() : null);
    }

    /** Ham cihaz kimliginin HMAC-SHA256 ozeti (kucuk harfli hex, 64 karakter). */
    public String hash(String raw) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(raw.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException("HMAC kullanilamiyor", e);
        }
    }

    /** Ham kimlik gecerli bicimde mi (8-128 karakter). */
    public static boolean validRaw(String raw) {
        return raw != null && RAW_DEVICE.matcher(raw.trim()).matches();
    }

    /** Arayuz icin kisa ozet (ilk 8 karakter). */
    public static String shortHash(String hash) {
        return hash == null ? null : hash.substring(0, Math.min(8, hash.length()));
    }

    static String platform(String p) {
        if (p == null) {
            return "UNKNOWN";
        }
        String v = p.trim().toUpperCase(Locale.ROOT);
        return v.equals("ANDROID") || v.equals("IOS") || v.equals("WEB") ? v : "UNKNOWN";
    }
}
