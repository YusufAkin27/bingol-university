package edu.bingol.backend.auth.oauth;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwsHeader;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.LocatorAdapter;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Date;
import java.util.Locale;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Google ID token'i ve Apple identity token'i dogrular. Kurallar (sirayla, hicbiri atlanamaz):
 * <ul>
 *   <li>yalniz RS256 (none ve HS* reddedilir; anahtar {@code kid} ile JWKS'ten, bkz. {@link OAuthKeyProvider});</li>
 *   <li>imza + {@code exp} (60 sn saat sapmasi toleransi); {@code iat} gelecekte ise (60 sn tolerans) reddedilir;</li>
 *   <li>{@code iss}: Google {@code accounts.google.com} | {@code https://accounts.google.com}, Apple {@code https://appleid.apple.com};</li>
 *   <li>{@code aud}: yapilandirilmis istemci kimlikleri beyaz listesinden biri (liste bossa HICBIR token gecmez);</li>
 *   <li>Google: {@code email_verified=true} zorunlu; Apple: {@code nonce} talebi = SHA-256(ham nonce) (hex);</li>
 * </ul>
 * Token'lar ve alt dizeleri LOG'A YAZILMAZ; hata nedeni yalniz kisa bir kod olarak loglanir. Hepsi ayni
 * {@code 400 OAUTH_TOKEN_INVALID} (neden istemciye sizdirilmaz); e-posta dogrulanmamissa {@code 403 OAUTH_EMAIL_UNVERIFIED}.
 */
@Component
public class OAuthTokenVerifier {

    private static final Logger log = LoggerFactory.getLogger(OAuthTokenVerifier.class);
    static final long SKEW_SECONDS = 60;
    static final Set<String> GOOGLE_ISSUERS = Set.of("accounts.google.com", "https://accounts.google.com");
    static final String APPLE_ISSUER = "https://appleid.apple.com";
    private static final int MAX_TOKEN_LEN = 8192;

    private final OAuthKeyProvider keys;
    private final OAuthProperties props;

    public OAuthTokenVerifier(OAuthKeyProvider keys, OAuthProperties props) {
        this.keys = keys;
        this.props = props;
    }

    public OAuthClaims verifyGoogle(String idToken) {
        Claims c = parse(OAuthProvider.GOOGLE, idToken);
        if (!GOOGLE_ISSUERS.contains(c.getIssuer())) {
            throw invalid("iss");
        }
        checkAudience(OAuthProvider.GOOGLE, c);
        String email = lower(c.get("email", String.class));
        if (email == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "OAUTH_EMAIL_MISSING", "E-posta alınamadı.");
        }
        if (!truthy(c.get("email_verified"))) {
            throw new ApiException(HttpStatus.FORBIDDEN, "OAUTH_EMAIL_UNVERIFIED", "E-posta doğrulanmamış.");
        }
        return new OAuthClaims(OAuthProvider.GOOGLE, subject(c), email, true, false,
                trimOrNull(c.get("given_name", String.class)), trimOrNull(c.get("family_name", String.class)));
    }

    /**
     * @param rawNonce istemcinin urettigi HAM nonce; Apple'a SHA-256(ham) (hex) verilir, token'daki {@code nonce} talebi
     *                 buna esit olmak zorundadir (yeniden oynatmaya karsi)
     */
    public OAuthClaims verifyApple(String identityToken, String rawNonce) {
        if (rawNonce == null || rawNonce.isBlank() || rawNonce.length() > 256) {
            throw invalid("nonce-missing");
        }
        Claims c = parse(OAuthProvider.APPLE, identityToken);
        if (!APPLE_ISSUER.equals(c.getIssuer())) {
            throw invalid("iss");
        }
        checkAudience(OAuthProvider.APPLE, c);
        String tokenNonce = c.get("nonce", String.class);
        String expected = Hashing.sha256(rawNonce);
        if (tokenNonce == null || !MessageDigest.isEqual(tokenNonce.toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8),
                expected.getBytes(StandardCharsets.UTF_8))) {
            throw invalid("nonce");
        }
        // E-posta yalniz ilk yetkilendirmede (ve ilk token'larda) gelebilir; yoksa saglayici kimligiyle eslesilir.
        String email = lower(c.get("email", String.class));
        boolean verified = email == null || truthy(c.get("email_verified"));
        if (!verified) {
            throw new ApiException(HttpStatus.FORBIDDEN, "OAUTH_EMAIL_UNVERIFIED", "E-posta doğrulanmamış.");
        }
        boolean priv = truthy(c.get("is_private_email")) || (email != null && email.endsWith("@privaterelay.appleid.com"));
        return new OAuthClaims(OAuthProvider.APPLE, subject(c), email, email != null, priv, null, null);
    }

    private Claims parse(OAuthProvider provider, String token) {
        if (token == null || token.isBlank() || token.length() > MAX_TOKEN_LEN) {
            throw invalid("empty");
        }
        try {
            return Jwts.parser()
                    .keyLocator(new LocatorAdapter<Key>() {
                        @Override
                        protected Key locate(JwsHeader header) {
                            if (!"RS256".equals(header.getAlgorithm())) {
                                return null; // none / HS* / diger algoritmalar: anahtar yok -> reddedilir
                            }
                            return keys.key(provider, header.getKeyId());
                        }
                    })
                    .clockSkewSeconds(SKEW_SECONDS)
                    .build()
                    .parseSignedClaims(token.trim())
                    .getPayload();
        } catch (JwtException | IllegalArgumentException e) {
            // Token'in kendisi/alt dizeleri loglanmaz; yalniz istisna turu
            throw invalid(e.getClass().getSimpleName());
        }
    }

    private void checkAudience(OAuthProvider provider, Claims c) {
        Set<String> aud = c.getAudience();
        var allowed = props.audiencesOf(provider);
        if (aud == null || allowed.isEmpty() || aud.stream().noneMatch(allowed::contains)) {
            throw invalid("aud");
        }
        Date iat = c.getIssuedAt();
        if (iat != null && iat.toInstant().isAfter(Instant.now().plusSeconds(SKEW_SECONDS))) {
            throw invalid("iat");
        }
    }

    private static String subject(Claims c) {
        String sub = c.getSubject();
        if (sub == null || sub.isBlank() || sub.length() > 255) {
            throw invalid("sub");
        }
        return sub;
    }

    private static boolean truthy(Object v) {
        return Boolean.TRUE.equals(v) || (v instanceof String s && "true".equalsIgnoreCase(s));
    }

    private static String lower(String s) {
        return s == null || s.isBlank() ? null : s.trim().toLowerCase(Locale.ROOT);
    }

    private static String trimOrNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static ApiException invalid(String reason) {
        log.info("OAuth token reddedildi: {}", reason);
        return new ApiException(HttpStatus.BAD_REQUEST, "OAUTH_TOKEN_INVALID", "Giriş doğrulanamadı.");
    }
}
