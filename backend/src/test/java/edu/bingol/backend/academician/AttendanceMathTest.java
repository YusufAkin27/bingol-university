package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import edu.bingol.backend.academician.AcAttendance.Method;
import edu.bingol.backend.academician.AcCourse.LimitType;
import edu.bingol.backend.academician.AttendanceMath.Rec;
import edu.bingol.backend.academician.AttendanceMath.Result;
import edu.bingol.backend.academician.AttendanceMath.Sess;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** "Hangi oturumlar bu ogrenci icin sayilir" tablosu: gec kayit, sayilmayan, izinli, kaldirilmis, canli, COUNT ve PERCENT (planlanan var/yok). */
class AttendanceMathTest {

    private static final Instant T0 = Instant.parse("2026-01-01T09:00:00Z");

    private static Instant t(int hours) {
        return T0.plusSeconds(3600L * hours);
    }

    private static Sess sess(long id, int openedHour, boolean live, boolean counted) {
        return new Sess(id, t(openedHour), live, counted);
    }

    private static Result run(List<Sess> ss, Instant addedAt, Map<Long, Rec> recs, LimitType type, Integer value, Integer planned) {
        return AttendanceMath.compute(ss, addedAt, recs, type, value, planned, 4);
    }

    private static final Rec QR = new Rec(Method.QR, false, false);
    private static final Rec MANUAL = new Rec(Method.MANUAL, false, false);
    private static final Rec REVOKED = new Rec(Method.QR, true, false);
    private static final Rec EXCUSED = new Rec(Method.MANUAL, false, true);

    @Test
    void presentAbsentAndRevoked() {
        List<Sess> ss = List.of(sess(1, 1, false, true), sess(2, 2, false, true), sess(3, 3, false, true));
        Result r = run(ss, t(0), Map.of(1L, QR, 2L, REVOKED), null, null, null);
        assertEquals(Map.of("1", "PRESENT_QR", "2", "REVOKED", "3", "ABSENT"), r.marks());
        assertEquals(3, r.sessionCount());
        assertEquals(1, r.present());
        assertEquals(2, r.absent());
    }

    @Test
    void lateEnrolmentDoesNotCountEarlierSessions() {
        List<Sess> ss = List.of(sess(1, 1, false, true), sess(2, 2, false, true), sess(3, 6, false, true));
        Result r = run(ss, t(5), Map.of(), LimitType.COUNT, 2, null);
        assertEquals("NOT_ENROLLED_YET", r.marks().get("1"));
        assertEquals("NOT_ENROLLED_YET", r.marks().get("2"));
        assertEquals("ABSENT", r.marks().get("3"));
        assertEquals(1, r.sessionCount());
        assertEquals(1, r.absent());
        assertEquals(1, r.level()); // 1 devamsizlik, sinir 2: bir tane daha sinira ulastirir
        // kaydi varsa onceki oturum yine sayilir (hoca elle isaretledi / bekleyen kabul)
        Result withRec = run(ss, t(5), Map.of(1L, MANUAL), null, null, null);
        assertEquals("PRESENT_MANUAL", withRec.marks().get("1"));
        assertEquals(2, withRec.sessionCount());
        assertEquals(1, withRec.present());
    }

    @Test
    void liveSessionsNeverCountButStayListed() {
        List<Sess> ss = List.of(sess(1, 1, false, true), sess(2, 2, true, true));
        Result r = run(ss, t(0), Map.of(), LimitType.COUNT, 1, null);
        assertEquals("ABSENT", r.marks().get("2")); // gecici
        assertEquals(1, r.sessionCount());
        assertEquals(1, r.absent());
        Result present = run(ss, t(0), Map.of(1L, QR, 2L, QR), null, null, null);
        assertEquals(1, present.sessionCount());
        assertEquals(1, present.present());
    }

    @Test
    void uncountedSessionKeepsMarksButIsExcludedFromTotals() {
        List<Sess> ss = List.of(sess(1, 1, false, false), sess(2, 2, false, true));
        Result r = run(ss, t(0), Map.of(1L, QR), LimitType.COUNT, 2, null);
        assertEquals("PRESENT_QR", r.marks().get("1"));
        assertEquals("ABSENT", r.marks().get("2"));
        assertEquals(1, r.sessionCount());
        assertEquals(0, r.present());
        assertEquals(1, r.absent());
        Result none = run(ss, t(0), Map.of(), null, null, null);
        assertEquals("ABSENT", none.marks().get("1"));
        assertEquals(1, none.absent()); // yalniz sayilan oturum
    }

    @Test
    void excusedIsNeitherPresentNorAbsentAndShrinksTheStudentsOwnTotal() {
        List<Sess> ss = List.of(sess(1, 1, false, true), sess(2, 2, false, true), sess(3, 3, false, true), sess(4, 4, false, true));
        Result r = run(ss, t(0), Map.of(1L, EXCUSED, 2L, QR), null, null, null);
        assertEquals("EXCUSED", r.marks().get("1"));
        assertEquals(3, r.sessionCount());
        assertEquals(1, r.present());
        assertEquals(2, r.absent());
        assertEquals(1, r.excused());
        // PERCENT planlanan yok: sayilan oturum 3 < 4 esigi: durum yok
        assertEquals(0, run(ss, t(0), Map.of(1L, EXCUSED), LimitType.PERCENT, 20, null).level());
    }

    @Test
    void countLimitSemantics() {
        List<Sess> ss = List.of(sess(1, 1, false, true), sess(2, 2, false, true), sess(3, 3, false, true), sess(4, 4, false, true));
        assertEquals(0, run(ss, t(0), Map.of(1L, QR, 2L, QR, 3L, QR, 4L, QR), LimitType.COUNT, 3, null).level());
        assertEquals(0, run(ss, t(0), Map.of(1L, QR, 2L, QR, 3L, QR), LimitType.COUNT, 3, null).level()); // 1 devamsizlik, sinir 3: henuz degil
        assertEquals(1, run(ss, t(0), Map.of(1L, QR, 2L, QR), LimitType.COUNT, 3, null).level());          // 2 devamsizlik: bir tane daha
        assertEquals(2, run(ss, t(0), Map.of(1L, QR), LimitType.COUNT, 3, null).level());                   // 3 = sinira ulasti
        assertEquals(2, run(ss, t(0), Map.of(), LimitType.COUNT, 3, null).level());                          // 4 = asildi
        assertEquals(3, run(ss, t(0), Map.of(), LimitType.COUNT, 3, null).allowedAbsences());
    }

    @Test
    void percentWithPlannedSessionsBehavesExactlyLikeCount() {
        List<Sess> ss = List.of(sess(1, 1, false, true), sess(2, 2, false, true), sess(3, 3, false, true));
        // %20 x 10 planlanan = 2 devamsizlik; ders sayisi (3) ne olursa olsun COUNT mantigi
        Result r1 = run(ss, t(0), Map.of(1L, QR, 2L, QR), LimitType.PERCENT, 20, 10);
        assertEquals(2, r1.allowedAbsences());
        assertEquals(1, r1.level()); // 1 devamsizlik, izinli 2: bir daha ulastirir
        assertEquals(2, run(ss, t(0), Map.of(1L, QR), LimitType.PERCENT, 20, 10).level()); // 2 = sinira ulasti
        // alt sinir: yuvarlama 0 verse de en az 1
        assertEquals(1, run(ss, t(0), Map.of(), LimitType.PERCENT, 5, 10).allowedAbsences());
        // floor: %25 x 10 = 2 (2,5 asagi)
        assertEquals(2, run(ss, t(0), Map.of(), LimitType.PERCENT, 25, 10).allowedAbsences());
    }

    @Test
    void percentWithoutPlannedNeedsMinimumCountedSessions() {
        List<Sess> three = List.of(sess(1, 1, false, true), sess(2, 2, false, true), sess(3, 3, false, true));
        Result r = run(three, t(0), Map.of(), LimitType.PERCENT, 20, null);
        assertEquals(0, r.level()); // 3 < 4: ilk kacirilan ders %100 gibi gorunmez
        assertNull(r.allowedAbsences());
        List<Sess> five = List.of(sess(1, 1, false, true), sess(2, 2, false, true), sess(3, 3, false, true), sess(4, 4, false, true),
                sess(5, 5, false, true));
        assertEquals(2, run(five, t(0), Map.of(1L, QR, 2L, QR, 3L, QR, 4L, QR), LimitType.PERCENT, 20, null).level()); // 1/5 = %20
        assertEquals(0, run(five, t(0), Map.of(1L, QR, 2L, QR, 3L, QR, 4L, QR, 5L, QR), LimitType.PERCENT, 20, null).level());
    }

    @Test
    void combinedLateEnrolmentUncountedExcusedRevokedAndLive() {
        List<Sess> ss = List.of(sess(1, 1, false, true),   // gec kayit: oncesi
                sess(2, 6, false, false),                    // sayilmiyor
                sess(3, 7, false, true),                     // izinli
                sess(4, 8, false, true),                     // kaldirilmis
                sess(5, 9, false, true),                     // yok
                sess(6, 10, true, true));                    // canli
        Result r = run(ss, t(5), Map.of(3L, EXCUSED, 4L, REVOKED), LimitType.COUNT, 3, null);
        assertEquals("NOT_ENROLLED_YET", r.marks().get("1"));
        assertEquals("ABSENT", r.marks().get("2"));
        assertEquals("EXCUSED", r.marks().get("3"));
        assertEquals("REVOKED", r.marks().get("4"));
        assertEquals(2, r.sessionCount());
        assertEquals(2, r.absent());
        assertEquals(1, r.excused());
        assertEquals(1, r.level()); // 2 devamsizlik, sinir 3
    }
}
