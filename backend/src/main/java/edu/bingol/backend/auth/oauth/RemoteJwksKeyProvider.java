package edu.bingol.backend.auth.oauth;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.math.BigInteger;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.function.LongSupplier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * Google/Apple JWKS anahtarlari. Adresler SABITTIR (SSRF yok; istemciden gelen hicbir deger URL'e girmez). Anahtarlar
 * {@value #TTL_MS} ms onbellekte tutulur; bilinmeyen {@code kid} gelirse (anahtar donusumu) en cok {@value #MIN_REFRESH_MS}
 * ms'de bir tek yenileme yapilir (sahte kid yagmuru saglayiciya istek firtinasina donusmez). Zaman asimi kisadir;
 * ulasilamazsa eldeki (eski) anahtarlarla devam edilir, hic yoksa null (fail-closed).
 */
@Component
public class RemoteJwksKeyProvider implements OAuthKeyProvider {

    private static final Logger log = LoggerFactory.getLogger(RemoteJwksKeyProvider.class);
    static final String GOOGLE_URL = "https://www.googleapis.com/oauth2/v3/certs";
    static final String APPLE_URL = "https://appleid.apple.com/auth/keys";
    static final long TTL_MS = 3_600_000L;
    static final long MIN_REFRESH_MS = 30_000L;
    private static final int MAX_BODY = 64 * 1024;

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Jwk(String kty, String kid, String alg, String use, String n, String e) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Jwks(List<Jwk> keys) {
    }

    private static final class Entry {
        volatile Map<String, PublicKey> keys = Map.of();
        volatile long loadedAt;
        volatile long lastAttempt;
        volatile boolean attempted;
    }

    private final Function<OAuthProvider, String> fetcher;
    private final LongSupplier clock;
    private final JsonMapper json = JsonMapper.builder().build();
    private final Map<OAuthProvider, Entry> cache = new java.util.concurrent.ConcurrentHashMap<>();

    @Autowired
    public RemoteJwksKeyProvider() {
        this(new HttpFetcher(), System::currentTimeMillis);
    }

    /** Testler icin: ag yerine sahte getirici ve saat. */
    RemoteJwksKeyProvider(Function<OAuthProvider, String> fetcher, LongSupplier clock) {
        this.fetcher = fetcher;
        this.clock = clock;
    }

    @Override
    public PublicKey key(OAuthProvider provider, String kid) {
        if (kid == null || kid.isBlank() || kid.length() > 128) {
            return null;
        }
        Entry e = cache.computeIfAbsent(provider, p -> new Entry());
        long now = clock.getAsLong();
        PublicKey k = e.keys.get(kid);
        boolean fresh = now - e.loadedAt < TTL_MS;
        if (k != null && fresh) {
            return k;
        }
        // Eksik anahtar ya da suresi dolmus onbellek: tek yenileme (en sik MIN_REFRESH_MS'de bir)
        synchronized (e) {
            now = clock.getAsLong();
            k = e.keys.get(kid);
            if (k != null && now - e.loadedAt < TTL_MS) {
                return k;
            }
            if (!e.attempted || now - e.lastAttempt >= MIN_REFRESH_MS) {
                e.attempted = true;
                e.lastAttempt = now;
                refresh(provider, e, now);
            }
            return e.keys.get(kid);
        }
    }

    private void refresh(OAuthProvider provider, Entry e, long now) {
        try {
            String body = fetcher.apply(provider);
            Map<String, PublicKey> parsed = parse(body);
            if (!parsed.isEmpty()) {
                e.keys = parsed;
                e.loadedAt = now;
            }
        } catch (RuntimeException ex) {
            // Ulasilamadi: eski anahtarlar (varsa) kalir; token'lar dogrulanamazsa reddedilir
            log.warn("OAuth JWKS yenilenemedi ({}): {}", provider, ex.toString());
        }
    }

    Map<String, PublicKey> parse(String body) {
        Map<String, PublicKey> out = new HashMap<>();
        if (body == null || body.isBlank()) {
            return out;
        }
        Jwks jwks = json.readValue(body, Jwks.class);
        if (jwks == null || jwks.keys() == null) {
            return out;
        }
        for (Jwk j : jwks.keys()) {
            if (j == null || j.kid() == null || j.n() == null || j.e() == null || !"RSA".equals(j.kty())) {
                continue;
            }
            if (j.alg() != null && !"RS256".equals(j.alg())) {
                continue;
            }
            try {
                Base64.Decoder dec = Base64.getUrlDecoder();
                BigInteger n = new BigInteger(1, dec.decode(j.n()));
                BigInteger exp = new BigInteger(1, dec.decode(j.e()));
                out.put(j.kid(), KeyFactory.getInstance("RSA").generatePublic(new RSAPublicKeySpec(n, exp)));
            } catch (Exception ex) {
                log.warn("OAuth JWKS anahtari okunamadi (kid={}): {}", j.kid(), ex.toString());
            }
        }
        return out;
    }

    /** Sabit adresler; kisa zaman asimi; yonlendirme yok; govde siniri. */
    private static final class HttpFetcher implements Function<OAuthProvider, String> {
        private final HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2))
                .followRedirects(HttpClient.Redirect.NEVER).build();

        @Override
        public String apply(OAuthProvider p) {
            String url = p == OAuthProvider.GOOGLE ? GOOGLE_URL : APPLE_URL;
            try {
                HttpRequest req = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(3))
                        .header("Accept", "application/json").GET().build();
                HttpResponse<java.io.InputStream> res = client.send(req, HttpResponse.BodyHandlers.ofInputStream());
                try (java.io.InputStream in = res.body()) {
                    if (res.statusCode() != 200) {
                        throw new IllegalStateException("HTTP " + res.statusCode());
                    }
                    byte[] bytes = in.readNBytes(MAX_BODY + 1);
                    if (bytes.length > MAX_BODY) {
                        throw new IllegalStateException("JWKS cok buyuk");
                    }
                    return new String(bytes, StandardCharsets.UTF_8);
                }
            } catch (InterruptedException ex) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("kesildi", ex);
            } catch (java.io.IOException ex) {
                throw new IllegalStateException(ex);
            }
        }
    }
}
