package edu.bingol.backend.auth.token;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.auth.FakeRedis;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.AuthProperties;
import edu.bingol.backend.config.JwtProperties;
import java.time.Duration;
import org.junit.jupiter.api.Test;

/** Cok oturum: refresh kaydindaki oturum kimligi (sid) tasinir, rotasyonda korunur, tek basina iptal edilebilir. */
class RefreshTokenSidTest {

    private final FakeRedis fake = new FakeRedis();
    private final RefreshTokenService service = new RefreshTokenService(fake.template,
            new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30),
            new AuthProperties(Duration.ofHours(72), 90, Duration.ofMinutes(60), Duration.ZERO));

    @Test
    void sidIsStoredAsFourthFieldAndSurvivesConsume() {
        String t = service.issue(7L, "mobile", 1_700_000_000_000L, "abcd1234abcd1234abcd1234abcd1234");

        assertEquals("7:mobile:1700000000000:abcd1234abcd1234abcd1234abcd1234", fake.values.get("rt:" + Hashing.sha256(t)));
        RefreshTokenService.Session s = service.consumeSession(t);
        assertEquals(7L, s.userId());
        assertEquals("mobile", s.client());
        assertEquals(1_700_000_000_000L, s.authTimeMs());
        assertEquals("abcd1234abcd1234abcd1234abcd1234", s.sid());
    }

    @Test
    void issueWithoutSidKeepsTheLegacyThreeFieldFormat() {
        String t = service.issue(7L, "web", 1_700_000_000_000L);

        assertEquals("7:web:1700000000000", fake.values.get("rt:" + Hashing.sha256(t)));
        assertNull(service.consumeSession(t).sid());
    }

    @Test
    void legacyTwoFieldValueStillParses() {
        fake.values.put("rt:" + Hashing.sha256("old"), "7:mobile");

        RefreshTokenService.Session s = service.consumeSession("old");

        assertEquals("mobile", s.client());
        assertEquals(0L, s.authTimeMs());
        assertNull(s.sid());
    }

    @Test
    void reuseMarkCarriesTheSidSoTheSessionFamilyCanBeClosed() {
        String t = service.issue(7L, "mobile", 1_700_000_000_000L, "sid-one");
        service.consumeSession(t);

        RefreshTokenService.Reuse r = service.findReuse(t).orElseThrow();

        assertEquals("sid-one", r.sid());
        assertEquals(1_700_000_000_000L, r.authTimeMs());
        assertTrue(r.familyKnown());
    }

    @Test
    void revokeSidClosesOnlyThatSessionAndLeavesTheOthers() {
        String a = service.issue(7L, "mobile", 1_000L, "sid-a");
        String b = service.issue(7L, "mobile", 2_000L, "sid-b");
        String legacy = service.issue(7L, "mobile", 3_000L);

        assertEquals(1, service.revokeSid(7L, "sid-a"));

        assertNull(service.peekUserId(a));
        assertTrue(service.wasRevoked(a), "iptal mezar tasi: istemci SESSION_REPLACED ayirt edebilsin");
        assertNotNull(service.peekUserId(b));
        assertNotNull(service.peekUserId(legacy));
        assertFalse(service.wasRevoked(b));
    }

    @Test
    void revokeSidIgnoresBlankAndOtherUsers() {
        String a = service.issue(7L, "mobile", 1_000L, "sid-a");

        assertEquals(0, service.revokeSid(7L, null));
        assertEquals(0, service.revokeSid(7L, " "));
        assertEquals(0, service.revokeSid(8L, "sid-a"));
        assertNotNull(service.peekUserId(a));
    }

    @Test
    void revokeFamilyStillWorksWithSidBearingValues() {
        String a = service.issue(7L, "mobile", 1_000L, "sid-a");
        String b = service.issue(7L, "mobile", 2_000L, "sid-b");

        assertEquals(1, service.revokeFamily(7L, "mobile", 1_000L));

        assertNull(service.peekUserId(a));
        assertNotNull(service.peekUserId(b));
    }

    @Test
    void revokeReturnsTheConsumedSessionForLogout() {
        String a = service.issue(7L, "mobile", 1_000L, "sid-a");

        RefreshTokenService.Session ended = service.revoke(a);

        assertEquals("sid-a", ended.sid());
        assertNull(service.revoke(a), "ikinci cikis: token yok");
        assertNull(service.findReuse(a).orElse(null), "cikis calinma isareti birakmaz");
    }
}
