package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.config.JwtProperties;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class CheckinCodeServiceTest {

    private final CheckinCodeService codes =
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    // 30 sn'lik pencerenin basinda sabit bir an (1_800_000_000 / 30 tam bolunur)
    private final Instant t0 = Instant.ofEpochSecond(1_800_000_000L);

    @Test
    void codeVerifiesInSameWindow() {
        String code = codes.generate(7, t0);

        assertTrue(codes.verify(7, code, t0));
        assertTrue(codes.verify(7, code, t0.plusSeconds(29)));
    }

    @Test
    void codeStillValidInNextWindowButNotAfter() {
        String code = codes.generate(7, t0);

        assertTrue(codes.verify(7, code, t0.plusSeconds(30)));
        assertTrue(codes.verify(7, code, t0.plusSeconds(59)));
        assertFalse(codes.verify(7, code, t0.plusSeconds(60)));
        assertFalse(codes.verify(7, code, t0.plusSeconds(3600)));
    }

    @Test
    void expiresAtMatchesLastAcceptedInstant() {
        String code = codes.generate(7, t0.plusSeconds(10));
        Instant exp = codes.expiresAt(t0.plusSeconds(10));

        assertTrue(codes.verify(7, code, exp.minusSeconds(1)));
        assertFalse(codes.verify(7, code, exp));
    }

    @Test
    void codeFromTheFutureIsRejected() {
        String future = codes.generate(7, t0.plusSeconds(120));

        assertFalse(codes.verify(7, future, t0));
    }

    @Test
    void codeIsBoundToEvent() {
        String code = codes.generate(7, t0);

        assertFalse(codes.verify(8, code, t0));
    }

    @Test
    void tamperedOrMalformedCodesAreRejected() {
        String code = codes.generate(7, t0);
        String[] p = code.split("\\.");
        String forged = p[0] + "." + p[1] + "." + "A".repeat(p[2].length());

        assertFalse(codes.verify(7, forged, t0));
        assertFalse(codes.verify(7, p[0] + "." + (Long.parseLong(p[1]) + 1) + "." + p[2], t0.plusSeconds(30)));
        assertFalse(codes.verify(7, "garbage", t0));
        assertFalse(codes.verify(7, "", t0));
        assertFalse(codes.verify(7, null, t0));
        assertFalse(codes.verify(7, "7.x.y", t0));
    }

    @Test
    void manualCodeIsSixSafeCharsAndVerifies() {
        String m = codes.generateManual(7, t0);

        assertEquals(6, m.length());
        assertTrue(m.matches("[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]{6}"), m);
        assertTrue(CheckinCodeService.looksManual(m));
        assertTrue(codes.verify(7, m, t0));
        assertTrue(codes.verify(7, m, t0.plusSeconds(59)));
        assertFalse(codes.verify(7, m, t0.plusSeconds(60)));
    }

    @Test
    void manualCodeToleratesCaseAndSeparators() {
        String m = codes.generateManual(7, t0);

        assertTrue(codes.verify(7, m.toLowerCase(java.util.Locale.ROOT), t0));
        assertTrue(codes.verify(7, m.substring(0, 3) + "-" + m.substring(3), t0));
        assertTrue(codes.verify(7, " " + m + " ", t0));
    }

    @Test
    void manualCodeIsBoundToEventAndWindowAndSecret() {
        String m = codes.generateManual(7, t0);

        assertFalse(codes.verify(8, m, t0));
        assertFalse(codes.verify(7, m, t0.minusSeconds(60))); // gelecekteki pencerenin kodu
        assertFalse(codes.verify(7, "AAAAAA", t0));
        assertFalse(codes.verify(7, "ABC", t0));
        CheckinCodeService other =
                new CheckinCodeService(new JwtProperties("another-secret-another-secret-123456", 15, 30));
        assertFalse(other.verify(7, m, t0));
    }

    @Test
    void qrPayloadIsNotManual() {
        assertFalse(CheckinCodeService.looksManual(codes.generate(7, t0)));
        assertFalse(CheckinCodeService.looksManual(null));
    }

    @Test
    void differentSecretProducesDifferentCodes() {
        CheckinCodeService other =
                new CheckinCodeService(new JwtProperties("another-secret-another-secret-123456", 15, 30));

        assertFalse(other.verify(7, codes.generate(7, t0), t0));
        assertEquals(codes.generate(7, t0), codes.generate(7, t0));
    }
}
