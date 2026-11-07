package edu.bingol.backend.auth.oauth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPublicKey;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

/** JWKS onbellegi: TTL, bilinmeyen kid icin tek yenileme (+ sinirlama), ulasilamazken fail-closed. */
class RemoteJwksKeyProviderTest {

    private static RSAPublicKey newKey() throws Exception {
        KeyPairGenerator g = KeyPairGenerator.getInstance("RSA");
        g.initialize(2048);
        return (RSAPublicKey) g.generateKeyPair().getPublic();
    }

    private static String jwks(String kid, RSAPublicKey k) {
        Base64.Encoder enc = Base64.getUrlEncoder().withoutPadding();
        String n = enc.encodeToString(unsigned(k.getModulus().toByteArray()));
        String e = enc.encodeToString(unsigned(k.getPublicExponent().toByteArray()));
        return "{\"keys\":[{\"kty\":\"RSA\",\"alg\":\"RS256\",\"use\":\"sig\",\"kid\":\"" + kid + "\",\"n\":\"" + n
                + "\",\"e\":\"" + e + "\",\"extra\":\"yoksayilir\"},"
                + "{\"kty\":\"EC\",\"kid\":\"ec-key\",\"crv\":\"P-256\"},"
                + "{\"kty\":\"RSA\",\"alg\":\"RS512\",\"kid\":\"rs512\",\"n\":\"AQAB\",\"e\":\"AQAB\"}]}";
    }

    private static byte[] unsigned(byte[] b) {
        return b.length > 1 && b[0] == 0 ? java.util.Arrays.copyOfRange(b, 1, b.length) : b;
    }

    @Test
    void parsesRsaKeysAndIgnoresUnsupportedOnes() throws Exception {
        RSAPublicKey k = newKey();
        AtomicLong now = new AtomicLong(1_000);
        RemoteJwksKeyProvider p = new RemoteJwksKeyProvider(prov -> jwks("k1", k), now::get);

        assertEquals(k, p.key(OAuthProvider.GOOGLE, "k1"));
        assertNull(p.key(OAuthProvider.GOOGLE, "ec-key")); // RSA degil
        assertNull(p.key(OAuthProvider.GOOGLE, "rs512")); // RS256 disi
        assertNull(p.key(OAuthProvider.GOOGLE, null));
    }

    @Test
    void cachesWithinTtlAndRefreshesAfterIt() throws Exception {
        RSAPublicKey k = newKey();
        AtomicInteger fetches = new AtomicInteger();
        AtomicLong now = new AtomicLong(1_000);
        RemoteJwksKeyProvider p = new RemoteJwksKeyProvider(prov -> {
            fetches.incrementAndGet();
            return jwks("k1", k);
        }, now::get);

        p.key(OAuthProvider.GOOGLE, "k1");
        p.key(OAuthProvider.GOOGLE, "k1");
        now.addAndGet(10 * 60_000L);
        p.key(OAuthProvider.GOOGLE, "k1");
        assertEquals(1, fetches.get());

        now.addAndGet(RemoteJwksKeyProvider.TTL_MS);
        assertNotNull(p.key(OAuthProvider.GOOGLE, "k1"));
        assertEquals(2, fetches.get());
    }

    @Test
    void unknownKidTriggersOneThrottledRefresh() throws Exception {
        RSAPublicKey oldKey = newKey();
        RSAPublicKey rotated = newKey();
        AtomicReference<String> body = new AtomicReference<>(jwks("old", oldKey));
        AtomicInteger fetches = new AtomicInteger();
        AtomicLong now = new AtomicLong(0);
        RemoteJwksKeyProvider p = new RemoteJwksKeyProvider(prov -> {
            fetches.incrementAndGet();
            return body.get();
        }, now::get);

        assertEquals(oldKey, p.key(OAuthProvider.APPLE, "old"));
        assertEquals(1, fetches.get());

        // sahte kid yagmuru: sinir araliginda ek getirme YOK
        for (int i = 0; i < 20; i++) {
            assertNull(p.key(OAuthProvider.APPLE, "sahte-" + i));
        }
        assertEquals(1, fetches.get());

        // anahtar donusumu: aralik gectikten sonra bilinmeyen kid TEK yenileme yapar ve yeni anahtari bulur
        body.set(jwks("new", rotated));
        now.addAndGet(RemoteJwksKeyProvider.MIN_REFRESH_MS + 1);
        assertEquals(rotated, p.key(OAuthProvider.APPLE, "new"));
        assertEquals(2, fetches.get());
    }

    @Test
    void unreachableProviderFailsClosedButKeepsKnownKeys() throws Exception {
        RSAPublicKey k = newKey();
        AtomicLong now = new AtomicLong(0);
        AtomicInteger calls = new AtomicInteger();
        RemoteJwksKeyProvider p = new RemoteJwksKeyProvider(prov -> {
            if (calls.getAndIncrement() == 0) {
                return jwks("k1", k);
            }
            throw new IllegalStateException("ag yok");
        }, now::get);

        assertEquals(k, p.key(OAuthProvider.GOOGLE, "k1"));
        now.addAndGet(RemoteJwksKeyProvider.TTL_MS + RemoteJwksKeyProvider.MIN_REFRESH_MS);
        // TTL doldu, yenileme basarisiz: eldeki anahtar kullanilmaya devam eder (kesinti tum girisleri dusurmesin)
        assertEquals(k, p.key(OAuthProvider.GOOGLE, "k1"));
        // hic bilinmeyen kid: null (token reddedilir)
        assertNull(p.key(OAuthProvider.GOOGLE, "yok"));

        RemoteJwksKeyProvider cold = new RemoteJwksKeyProvider(prov -> {
            throw new IllegalStateException("ag yok");
        }, now::get);
        assertNull(cold.key(OAuthProvider.APPLE, "k1")); // soguk baslangic + ulasilamaz = fail-closed
    }

    @Test
    void garbageBodyYieldsNoKeys() {
        RemoteJwksKeyProvider p = new RemoteJwksKeyProvider(prov -> "<html>hata</html>", System::currentTimeMillis);
        assertNull(p.key(OAuthProvider.GOOGLE, "k1"));
    }
}
