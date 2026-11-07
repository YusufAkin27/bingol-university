package edu.bingol.backend.auth.oauth;

import edu.bingol.backend.common.Hashing;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PublicKey;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * OAuth testleri icin yerel RSA anahtari + imzali token uretici. Gercek ag YOK: {@link OAuthKeyProvider} yerel
 * anahtari doner, saglayici JWKS'i hic cagrilmaz.
 */
final class OAuthTestSupport {

    static final String GOOGLE_AUD = "google-web-client.apps.googleusercontent.com";
    static final String APPLE_AUD = "tr.com.bukampus.app";
    static final String KID = "test-kid-1";

    final KeyPair pair;
    final KeyPair otherPair;
    final OAuthProperties props;
    final OAuthKeyProvider keys;
    final OAuthTokenVerifier verifier;

    OAuthTestSupport() {
        this(true);
    }

    OAuthTestSupport(boolean enabled) {
        try {
            KeyPairGenerator g = KeyPairGenerator.getInstance("RSA");
            g.initialize(2048);
            pair = g.generateKeyPair();
            otherPair = g.generateKeyPair();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
        props = new OAuthProperties(enabled, List.of(GOOGLE_AUD, "google-android.apps.googleusercontent.com"),
                List.of(APPLE_AUD), true, false);
        PublicKey pub = pair.getPublic();
        keys = (provider, kid) -> KID.equals(kid) ? pub : null;
        verifier = new OAuthTokenVerifier(keys, props);
    }

    /** Gecerli Google token talepleri (testler istedigini ezer). */
    Map<String, Object> googleClaims(String sub, String email) {
        Map<String, Object> c = new HashMap<>();
        c.put("iss", "https://accounts.google.com");
        c.put("aud", GOOGLE_AUD);
        c.put("sub", sub);
        c.put("email", email);
        c.put("email_verified", true);
        c.put("given_name", "Ayşe");
        c.put("family_name", "Yılmaz");
        return c;
    }

    Map<String, Object> appleClaims(String sub, String email, String rawNonce) {
        Map<String, Object> c = new HashMap<>();
        c.put("iss", "https://appleid.apple.com");
        c.put("aud", APPLE_AUD);
        c.put("sub", sub);
        if (email != null) {
            c.put("email", email);
            c.put("email_verified", "true");
        }
        if (rawNonce != null) {
            c.put("nonce", Hashing.sha256(rawNonce));
        }
        return c;
    }

    String sign(Map<String, Object> claims) {
        return sign(claims, KID, pair, Instant.now().minusSeconds(5), Instant.now().plusSeconds(600));
    }

    String sign(Map<String, Object> claims, String kid, KeyPair signer, Instant iat, Instant exp) {
        var b = Jwts.builder().header().keyId(kid).and().claims(claims);
        b.issuedAt(Date.from(iat)).expiration(Date.from(exp));
        return b.signWith(signer.getPrivate(), Jwts.SIG.RS256).compact();
    }

    /** alg=none (imzasiz) token. */
    static String unsecured(Map<String, Object> claims) {
        try {
            String h = b64("{\"alg\":\"none\",\"kid\":\"" + KID + "\"}");
            StringBuilder p = new StringBuilder("{");
            boolean first = true;
            for (var e : claims.entrySet()) {
                p.append(first ? "" : ",").append('"').append(e.getKey()).append("\":");
                Object v = e.getValue();
                p.append(v instanceof Boolean ? v.toString() : '"' + v.toString() + '"');
                first = false;
            }
            p.append(",\"exp\":").append(Instant.now().plusSeconds(600).getEpochSecond()).append('}');
            return h + "." + b64(p.toString()) + ".";
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    /** HS256 ile, RSA ACIK anahtari bayt olarak HMAC sirri yapilmis token (algoritma karistirma saldirisi). */
    String hmacConfusion(Map<String, Object> claims) {
        var secret = Keys.hmacShaKeyFor(java.util.Arrays.copyOf(
                (Base64.getEncoder().encodeToString(pair.getPublic().getEncoded()) + "padding-padding-padding")
                        .getBytes(StandardCharsets.UTF_8), 64));
        return Jwts.builder().header().keyId(KID).and().claims(claims)
                .expiration(Date.from(Instant.now().plusSeconds(600))).signWith(secret, Jwts.SIG.HS256).compact();
    }

    private static String b64(String s) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(s.getBytes(StandardCharsets.UTF_8));
    }
}
