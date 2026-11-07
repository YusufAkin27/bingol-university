package edu.bingol.backend.notification.live;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * APNs dogrudan Canli Etkinlik push'u ({@code apns-push-type: liveactivity}, topic {@code <bundle>.push-type.liveactivity}).
 * FCM Canli Etkinlik jetonunu iletemez, bu yuzden .p8 anahtarla (token tabanli kimlik) HTTP/2 ile gonderilir.
 *
 * <p>YAPILANDIRMA YOKSA DEVRE DISI: {@code APNS_KEY_ID}, {@code APNS_TEAM_ID}, {@code APNS_BUNDLE_ID} ve anahtar
 * ({@code APNS_KEY_BASE64} ya da {@code APNS_KEY_FILE}) girilmeden {@link #configured()} false doner ve hicbir sey gonderilmez.
 * Gonderim metotlari cagirana istisna sizdirmaz.
 */
@Component
public class ApnsLiveActivitySender {

    private static final Logger log = LoggerFactory.getLogger(ApnsLiveActivitySender.class);
    private static final ObjectMapper JSON = new ObjectMapper();

    private final String keyId;
    private final String teamId;
    private final String bundleId;
    private final String keyBase64;
    private final String keyFile;
    private final boolean production;
    private final HttpClient http = HttpClient.newBuilder().version(HttpClient.Version.HTTP_2)
            .connectTimeout(Duration.ofSeconds(5)).build();

    private volatile PrivateKey key;
    private volatile String cachedJwt;
    private volatile Instant jwtAt = Instant.EPOCH;

    public ApnsLiveActivitySender(@Value("${app.apns.key-id:}") String keyId,
                                  @Value("${app.apns.team-id:}") String teamId,
                                  @Value("${app.apns.bundle-id:}") String bundleId,
                                  @Value("${app.apns.key-base64:}") String keyBase64,
                                  @Value("${app.apns.key-file:}") String keyFile,
                                  @Value("${app.apns.production:true}") boolean production) {
        this.keyId = keyId;
        this.teamId = teamId;
        this.bundleId = bundleId;
        this.keyBase64 = keyBase64;
        this.keyFile = keyFile;
        this.production = production;
    }

    public boolean configured() {
        return !keyId.isBlank() && !teamId.isBlank() && !bundleId.isBlank()
                && (!keyBase64.isBlank() || !keyFile.isBlank());
    }

    /** Canli Etkinligi bitirir (kullanici etkinlik/sinav iptal olunca ekrandan kalksin). */
    public boolean end(String deviceToken, Map<String, Object> finalState) {
        return send(deviceToken, "end", finalState);
    }

    public boolean update(String deviceToken, Map<String, Object> state) {
        return send(deviceToken, "update", state);
    }

    boolean send(String deviceToken, String event, Map<String, Object> contentState) {
        if (!configured() || deviceToken == null || deviceToken.isBlank()) {
            return false;
        }
        try {
            Map<String, Object> aps = new LinkedHashMap<>();
            aps.put("timestamp", Instant.now().getEpochSecond());
            aps.put("event", event);
            aps.put("content-state", contentState);
            if ("end".equals(event)) {
                aps.put("dismissal-date", Instant.now().getEpochSecond());
            }
            String body = JSON.writeValueAsString(Map.of("aps", aps));
            String host = production ? "api.push.apple.com" : "api.sandbox.push.apple.com";
            HttpRequest req = HttpRequest.newBuilder(URI.create("https://" + host + "/3/device/" + deviceToken))
                    .timeout(Duration.ofSeconds(10))
                    .header("authorization", "bearer " + jwt())
                    .header("apns-push-type", "liveactivity")
                    .header("apns-topic", bundleId + ".push-type.liveactivity")
                    .header("apns-priority", "10")
                    .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
                    .build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) {
                // Jeton/govde log'a yazilmaz; yalniz durum ve APNs gerekcesi.
                log.warn("APNs liveactivity red: {} {}", res.statusCode(), res.body());
                return false;
            }
            return true;
        } catch (Exception e) {
            log.warn("APNs liveactivity gonderilemedi: {}", e.toString());
            return false;
        }
    }

    private synchronized String jwt() throws Exception {
        if (cachedJwt != null && Instant.now().isBefore(jwtAt.plus(Duration.ofMinutes(40)))) {
            return cachedJwt;
        }
        String header = b64(JSON.writeValueAsBytes(Map.of("alg", "ES256", "kid", keyId)));
        String claims = b64(JSON.writeValueAsBytes(Map.of("iss", teamId, "iat", Instant.now().getEpochSecond())));
        Signature sig = Signature.getInstance("SHA256withECDSAinP1363Format");
        sig.initSign(privateKey());
        sig.update((header + "." + claims).getBytes(StandardCharsets.US_ASCII));
        cachedJwt = header + "." + claims + "." + b64(sig.sign());
        jwtAt = Instant.now();
        return cachedJwt;
    }

    private PrivateKey privateKey() throws Exception {
        if (key == null) {
            String pem = !keyBase64.isBlank()
                    ? new String(Base64.getDecoder().decode(keyBase64.trim()), StandardCharsets.UTF_8)
                    : Files.readString(Path.of(keyFile));
            String der = pem.replaceAll("-----[A-Z ]+-----", "").replaceAll("\\s", "");
            key = KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(der)));
        }
        return key;
    }

    private static String b64(byte[] b) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }
}
