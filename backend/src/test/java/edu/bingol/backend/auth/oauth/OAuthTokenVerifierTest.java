package edu.bingol.backend.auth.oauth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Google/Apple token dogrulamasi: yerel RSA anahtariyla uretilen token'lar, ag yok. */
class OAuthTokenVerifierTest {

    private final OAuthTestSupport t = new OAuthTestSupport();

    private void assertInvalid(Runnable r) {
        ApiException e = assertThrows(ApiException.class, r::run);
        assertEquals("OAUTH_TOKEN_INVALID", e.code());
        assertEquals(400, e.status().value());
    }

    // ------------------------------------------------------------------ Google

    @Test
    void validGoogleTokenYieldsNormalizedClaims() {
        OAuthClaims c = t.verifier.verifyGoogle(t.sign(t.googleClaims("g-sub-1", "  Ayse.Yilmaz@GMail.com ")));

        assertEquals(OAuthProvider.GOOGLE, c.provider());
        assertEquals("g-sub-1", c.subject());
        assertEquals("ayse.yilmaz@gmail.com", c.email()); // kucuk harf + kirpilmis
        assertTrue(c.emailVerified());
        assertFalse(c.emailPrivate());
        assertEquals("Ayşe", c.givenName());
        assertEquals("Yılmaz", c.familyName());
    }

    @Test
    void googleAcceptsEveryConfiguredClientIdAndAudienceArrays() {
        Map<String, Object> android = t.googleClaims("s", "a@gmail.com");
        android.put("aud", "google-android.apps.googleusercontent.com");
        assertEquals("s", t.verifier.verifyGoogle(t.sign(android)).subject());

        Map<String, Object> arr = t.googleClaims("s2", "a@gmail.com");
        arr.put("aud", List.of("baska-istemci", OAuthTestSupport.GOOGLE_AUD));
        assertEquals("s2", t.verifier.verifyGoogle(t.sign(arr)).subject());
    }

    @Test
    void googleBothIssuerSpellingsPassOthersFail() {
        Map<String, Object> c = t.googleClaims("s", "a@gmail.com");
        c.put("iss", "accounts.google.com");
        assertEquals("s", t.verifier.verifyGoogle(t.sign(c)).subject());

        c.put("iss", "https://evil.example.com");
        assertInvalid(() -> t.verifier.verifyGoogle(t.sign(c)));
        c.put("iss", "https://appleid.apple.com"); // baska saglayicinin iss'i Google'da gecmez
        assertInvalid(() -> t.verifier.verifyGoogle(t.sign(c)));
    }

    @Test
    void googleWrongAudienceIsRejected() {
        Map<String, Object> c = t.googleClaims("s", "a@gmail.com");
        c.put("aud", "baska-uygulama.apps.googleusercontent.com");
        assertInvalid(() -> t.verifier.verifyGoogle(t.sign(c)));
    }

    @Test
    void emptyAudienceWhitelistRejectsEverything() {
        OAuthProperties empty = new OAuthProperties(true, List.of(), List.of(), true, false);
        OAuthTokenVerifier v = new OAuthTokenVerifier(t.keys, empty);
        assertInvalid(() -> v.verifyGoogle(t.sign(t.googleClaims("s", "a@gmail.com"))));
        assertInvalid(() -> v.verifyApple(t.sign(t.appleClaims("s", "a@x.com", "n")), "n"));
    }

    @Test
    void expiredTokenIsRejectedButSmallClockSkewIsTolerated() {
        Map<String, Object> c = t.googleClaims("s", "a@gmail.com");
        String old = t.sign(c, OAuthTestSupport.KID, t.pair, Instant.now().minusSeconds(4000), Instant.now().minusSeconds(3600));
        assertInvalid(() -> t.verifier.verifyGoogle(old));

        String justExpired = t.sign(c, OAuthTestSupport.KID, t.pair, Instant.now().minusSeconds(700), Instant.now().minusSeconds(30));
        assertEquals("s", t.verifier.verifyGoogle(justExpired).subject()); // 60 sn tolerans icinde
    }

    @Test
    void tokenIssuedFarInTheFutureIsRejected() {
        Map<String, Object> c = t.googleClaims("s", "a@gmail.com");
        String future = t.sign(c, OAuthTestSupport.KID, t.pair, Instant.now().plusSeconds(3600), Instant.now().plusSeconds(7200));
        assertInvalid(() -> t.verifier.verifyGoogle(future));
    }

    @Test
    void algNoneAndHmacConfusionAreRejected() {
        assertInvalid(() -> t.verifier.verifyGoogle(OAuthTestSupport.unsecured(t.googleClaims("s", "a@gmail.com"))));
        assertInvalid(() -> t.verifier.verifyGoogle(t.hmacConfusion(t.googleClaims("s", "a@gmail.com"))));
        assertInvalid(() -> t.verifier.verifyApple(OAuthTestSupport.unsecured(t.appleClaims("s", "a@x.com", "n")), "n"));
    }

    @Test
    void wrongSignatureOrUnknownKidIsRejected() {
        Map<String, Object> c = t.googleClaims("s", "a@gmail.com");
        // baska anahtarla imzali (kid ayni)
        String forged = t.sign(c, OAuthTestSupport.KID, t.otherPair, Instant.now().minusSeconds(5), Instant.now().plusSeconds(600));
        assertInvalid(() -> t.verifier.verifyGoogle(forged));
        // bilinmeyen kid
        String unknownKid = t.sign(c, "bilinmeyen", t.pair, Instant.now().minusSeconds(5), Instant.now().plusSeconds(600));
        assertInvalid(() -> t.verifier.verifyGoogle(unknownKid));
    }

    @Test
    void garbageAndEmptyTokensAreRejected() {
        assertInvalid(() -> t.verifier.verifyGoogle(null));
        assertInvalid(() -> t.verifier.verifyGoogle("   "));
        assertInvalid(() -> t.verifier.verifyGoogle("a.b.c"));
        assertInvalid(() -> t.verifier.verifyGoogle("x".repeat(9000)));
    }

    @Test
    void googleUnverifiedEmailIs403AndStringTrueIsAccepted() {
        Map<String, Object> c = t.googleClaims("s", "a@gmail.com");
        c.put("email_verified", false);
        ApiException e = assertThrows(ApiException.class, () -> t.verifier.verifyGoogle(t.sign(c)));
        assertEquals("OAUTH_EMAIL_UNVERIFIED", e.code());
        assertEquals(403, e.status().value());

        c.put("email_verified", "true"); // bazi saglayicilar metin gonderir
        assertEquals("s", t.verifier.verifyGoogle(t.sign(c)).subject());
        c.remove("email_verified");
        assertEquals("OAUTH_EMAIL_UNVERIFIED", assertThrows(ApiException.class, () -> t.verifier.verifyGoogle(t.sign(c))).code());
    }

    @Test
    void googleWithoutEmailIsEmailMissing() {
        Map<String, Object> c = t.googleClaims("s", "a@gmail.com");
        c.remove("email");
        assertEquals("OAUTH_EMAIL_MISSING", assertThrows(ApiException.class, () -> t.verifier.verifyGoogle(t.sign(c))).code());
    }

    // ------------------------------------------------------------------ Apple

    @Test
    void validAppleTokenWithMatchingNonce() {
        OAuthClaims c = t.verifier.verifyApple(t.sign(t.appleClaims("a-sub-1", "Kisi@Icloud.com", "ham-nonce-123")), "ham-nonce-123");

        assertEquals(OAuthProvider.APPLE, c.provider());
        assertEquals("a-sub-1", c.subject());
        assertEquals("kisi@icloud.com", c.email());
        assertFalse(c.emailPrivate());
        assertNull(c.givenName()); // Apple adi token'da yok; istemci iletir
    }

    @Test
    void appleNonceMismatchOrMissingIsRejected() {
        String token = t.sign(t.appleClaims("s", "a@x.com", "dogru-nonce"));
        assertInvalid(() -> t.verifier.verifyApple(token, "yanlis-nonce"));
        assertInvalid(() -> t.verifier.verifyApple(token, null));
        assertInvalid(() -> t.verifier.verifyApple(token, "  "));
        // token'da nonce talebi yok
        String noNonce = t.sign(t.appleClaims("s", "a@x.com", null));
        assertInvalid(() -> t.verifier.verifyApple(noNonce, "dogru-nonce"));
        // ham degerin kendisi (SHA-256 uygulanmamis) nonce talebi olarak KABUL EDILMEZ
        Map<String, Object> raw = t.appleClaims("s", "a@x.com", null);
        raw.put("nonce", "dogru-nonce");
        assertInvalid(() -> t.verifier.verifyApple(t.sign(raw), "dogru-nonce"));
    }

    @Test
    void applePrivateRelayEmailIsAcceptedAndFlagged() {
        OAuthClaims c = t.verifier.verifyApple(
                t.sign(t.appleClaims("s", "abc123@privaterelay.appleid.com", "n1")), "n1");
        assertEquals("abc123@privaterelay.appleid.com", c.email());
        assertTrue(c.emailPrivate());

        Map<String, Object> flagged = t.appleClaims("s2", "x@icloud.com", "n2");
        flagged.put("is_private_email", "true");
        assertTrue(t.verifier.verifyApple(t.sign(flagged), "n2").emailPrivate());
    }

    @Test
    void appleWithoutEmailIsAcceptedBySubjectOnly() {
        OAuthClaims c = t.verifier.verifyApple(t.sign(t.appleClaims("s", null, "n")), "n");
        assertNull(c.email());
        assertEquals("s", c.subject());
    }

    @Test
    void appleWrongIssuerAudienceAndUnverifiedEmail() {
        Map<String, Object> c = t.appleClaims("s", "a@x.com", "n");
        c.put("iss", "https://accounts.google.com");
        assertInvalid(() -> t.verifier.verifyApple(t.sign(c), "n"));

        Map<String, Object> d = t.appleClaims("s", "a@x.com", "n");
        d.put("aud", "com.baska.uygulama");
        assertInvalid(() -> t.verifier.verifyApple(t.sign(d), "n"));

        Map<String, Object> e = t.appleClaims("s", "a@x.com", "n");
        e.put("email_verified", "false");
        assertEquals("OAUTH_EMAIL_UNVERIFIED", assertThrows(ApiException.class, () -> t.verifier.verifyApple(t.sign(e), "n")).code());
    }
}
