package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.config.JwtProperties;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Doner yoklama kodu: belirleyici MAC, guncel + onceki adim, eski/gelecek/oynanmis/bozuk kod reddi. */
class LessonCodeServiceTest {

    private static final String SECRET = "test-secret-test-secret-test-secret-1234";
    private final LessonCodeService svc = new LessonCodeService(new JwtProperties(SECRET, 15, 30));
    /** 5 sn adim sinirinin ortasinda sabit an (adim = 2_000_000_000 / 5 = 400_000_000). */
    private final Instant now = Instant.ofEpochSecond(2_000_000_002L);

    @Test
    void codeIsDeterministicAndWellFormed() {
        String a = svc.generate(42, now);
        assertEquals(a, svc.generate(42, now));
        assertEquals(a, svc.generate(42, now.plusSeconds(2))); // ayni 5 sn adimi
        assertTrue(a.matches("^bingol-lesson:42\\.400000000\\.[A-Za-z0-9_\\-]{22}$"), a);
        assertNotEquals(a, svc.generate(42, now.plusSeconds(5)));
        assertNotEquals(a, svc.generate(43, now));
    }

    @Test
    void currentAndPreviousStepAreAccepted() {
        assertEquals(42, svc.verify(svc.generate(42, now), now));
        assertEquals(42, svc.verify(svc.generate(42, now.minusSeconds(5)), now));
    }

    @Test
    void twoStepsOldIsRejected() {
        assertEquals(-1, svc.verify(svc.generate(42, now.minusSeconds(10)), now));
        assertEquals(-1, svc.verify(svc.generate(42, now.minusSeconds(3600)), now));
    }

    @Test
    void futureStepIsRejected() {
        assertEquals(-1, svc.verify(svc.generate(42, now.plusSeconds(5)), now));
        assertEquals(-1, svc.verify(svc.generate(42, now.plusSeconds(3600)), now));
    }

    @Test
    void codeForAnotherSessionIsRejectedAndSessionIdCannotBeSwapped() {
        String forA = svc.generate(7, now);
        // oturum numarasini degistirmek MAC'i bozar
        String swapped = forA.replace("bingol-lesson:7.", "bingol-lesson:8.");
        assertEquals(-1, svc.verify(swapped, now));
        assertEquals(7, svc.verify(forA, now)); // dogru oturum numarasini doner (cagiran oturumu bununla bulur)
    }

    @Test
    void tamperedMacIsRejected() {
        String code = svc.generate(42, now);
        String tampered = code.substring(0, code.length() - 1) + (code.endsWith("A") ? "B" : "A");
        assertEquals(-1, svc.verify(tampered, now));
        assertEquals(-1, svc.verify(code.substring(0, code.length() - 2), now));
    }

    @Test
    void differentSecretProducesDifferentCodes() {
        LessonCodeService other = new LessonCodeService(new JwtProperties("another-secret-another-secret-123456", 15, 30));
        assertEquals(-1, other.verify(svc.generate(42, now), now));
    }

    @Test
    void malformedAndOversizedInputIsRejected() {
        for (String bad : new String[] {null, "", "   ", "bingol-lesson:", "bingol-lesson:42", "bingol-lesson:42.400000000",
                "bingol-lesson:x.400000000.AAAA", "bingol-lesson:42.-1.AAAA", "bingol-clubjoin:42.400000000.AAAA",
                "42.400000000.AAAA", "bingol-lesson:42.400000000.AA AA", "bingol-lesson:99999999999999999999.4.AAAA"}) {
            assertEquals(-1, svc.verify(bad, now), String.valueOf(bad));
        }
        assertEquals(-1, svc.verify("bingol-lesson:42.400000000." + "A".repeat(400), now));
        assertEquals(-1, svc.verify("A".repeat(100_000), now));
    }

    @Test
    void upcomingGivesCurrentPlusNextTwoWithServerTimeWindows() {
        List<LessonCodeService.CodeWindow> w = svc.upcoming(42, now, 3);
        assertEquals(3, w.size());
        assertEquals(svc.generate(42, now), w.get(0).code());
        assertEquals(400_000_000L * 5000, w.get(0).fromMs());
        assertEquals(w.get(0).untilMs(), w.get(1).fromMs());
        assertEquals(w.get(1).untilMs(), w.get(2).fromMs());
        assertEquals(5000, w.get(0).untilMs() - w.get(0).fromMs());
        // ekranin onceden aldigi sonraki kod, zamani gelince gecerlidir
        assertEquals(42, svc.verify(w.get(1).code(), now.plusSeconds(5)));
    }
}
