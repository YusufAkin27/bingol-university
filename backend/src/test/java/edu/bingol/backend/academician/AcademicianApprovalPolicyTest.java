package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import edu.bingol.backend.academician.Academician.ApprovalMode;
import edu.bingol.backend.academician.Academician.Status;
import edu.bingol.backend.academician.AcademicianProperties.AutoApprove;
import edu.bingol.backend.user.User;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;

/** Otomatik onay kurali tablo testi (docs: STAFF_PATTERN / NEVER). */
class AcademicianApprovalPolicyTest {

    private static User user(String email, Consumer<User> tweak) {
        User u = new User();
        u.setEmail(email);
        u.setEmailVerified(true);
        tweak.accept(u);
        return u;
    }

    private static void expect(AutoApprove cfg, User u, Status status, ApprovalMode mode, String why) {
        AcademicianApprovalPolicy.Decision d = AcademicianApprovalPolicy.decide(cfg, u);
        assertEquals(status, d.status(), why);
        if (mode == null) {
            assertNull(d.mode(), why);
        } else {
            assertEquals(mode, d.mode(), why);
        }
    }

    @Test
    void staffPatternTable() {
        AutoApprove c = AutoApprove.STAFF_PATTERN;
        expect(c, user("x.y@bingol.edu.tr", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "ad.soyad kurumsal adres");
        expect(c, user("X.Y@Bingol.Edu.Tr", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "buyuk harf normallesir");
        expect(c, user("hoca1@bingol.edu.tr", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "harf + rakam");
        expect(c, user("220051010@bingol.edu.tr", u -> { }), Status.PENDING, null, "ogrenci numarasi");
        expect(c, user("2200510@bingol.edu.tr", u -> { }), Status.PENDING, null, "7 hane numara");
        expect(c, user("a@ogr.bingol.edu.tr", u -> { }), Status.PENDING, null, "alt alan adi");
        expect(c, user("a@bingol.edu.tr.evil.com", u -> { }), Status.PENDING, null, "taklit alan adi");
        expect(c, user("someone@gmail.com", u -> { }), Status.PENDING, null, "gmail");
        expect(c, user("x.y@bingol.edu.tr", u -> u.setVerificationDeferred(true)), Status.PENDING, null, "ertelenmis dogrulama");
        expect(c, user("x.y@bingol.edu.tr", u -> u.setEmailVerified(false)), Status.PENDING, null, "dogrulanmamis");
        expect(c, user("abc123@privaterelay.appleid.com", u -> u.setEmailRelay(true)), Status.PENDING, null, "Apple gizli adres");
        expect(c, user("x.y@bingol.edu.tr", u -> u.setEmailRelay(true)), Status.PENDING, null, "role isareti");
        expect(c, user("x.y@bingol.edu.tr", u -> u.setGrade("1")), Status.PENDING, null, "grade dolu");
        expect(c, user("x.y@bingol.edu.tr", u -> u.setClassYear((short) 2)), Status.PENDING, null, "classYear dolu");
        expect(c, user("", u -> { }), Status.PENDING, null, "bos");
    }

    @Test
    void neverAlwaysPending() {
        expect(AutoApprove.NEVER, user("x.y@bingol.edu.tr", u -> { }), Status.PENDING, null, "NEVER");
        expect(AutoApprove.NEVER, user("hoca@bingol.edu.tr", u -> { }), Status.PENDING, null, "NEVER");
    }

    @Test
    void studentNumberIsTheDigitsLocalPartOfACampusAddress() {
        assertEquals("220051010", AcademicianApprovalPolicy.studentNo("220051010@bingol.edu.tr"));
        assertNull(AcademicianApprovalPolicy.studentNo("x.y@bingol.edu.tr"));
        assertNull(AcademicianApprovalPolicy.studentNo("220051010@gmail.com"));
        assertNull(AcademicianApprovalPolicy.studentNo(null));
    }
}
