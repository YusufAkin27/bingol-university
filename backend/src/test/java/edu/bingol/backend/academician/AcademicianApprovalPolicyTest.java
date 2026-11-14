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
        expect(c, user("hoca1@bingol.edu.tr", u -> { }), Status.PENDING, null, "harf + rakam artik PENDING");
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
    void localPartMustBeLettersWithSingleSeparatorsAndNoDigits() {
        AutoApprove c = AutoApprove.STAFF_PATTERN;
        expect(c, user("a20211234@bingol.edu.tr", u -> { }), Status.PENDING, null, "harf + ogrenci numarasi");
        expect(c, user("ali2@bingol.edu.tr", u -> { }), Status.PENDING, null, "tek rakam");
        expect(c, user("ali.veli1@bingol.edu.tr", u -> { }), Status.PENDING, null, "sonda rakam");
        expect(c, user("ali.@bingol.edu.tr", u -> { }), Status.PENDING, null, "sonda ayirici");
        expect(c, user(".ali@bingol.edu.tr", u -> { }), Status.PENDING, null, "basta ayirici");
        expect(c, user("ali..veli@bingol.edu.tr", u -> { }), Status.PENDING, null, "cift ayirici");
        expect(c, user("ali.-veli@bingol.edu.tr", u -> { }), Status.PENDING, null, "ayirici dizisi");
        expect(c, user("ali+x@bingol.edu.tr", u -> { }), Status.PENDING, null, "+etiket");
        expect(c, user("ali.veli@bingol.edu.tr", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "ad.soyad");
        expect(c, user("ali_veli@bingol.edu.tr", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "alt cizgi");
        expect(c, user("ali-veli.yilmaz@bingol.edu.tr", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "tire + nokta");
        expect(c, user("ALI.VELI@BINGOL.EDU.TR", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "buyuk harf girdisi");
    }

    @Test
    void turkishDefaultLocaleDoesNotChangeTheDecision() {
        java.util.Locale old = java.util.Locale.getDefault();
        try {
            java.util.Locale.setDefault(java.util.Locale.forLanguageTag("tr-TR"));
            AutoApprove c = AutoApprove.STAFF_PATTERN;
            // Turkce yerelde "I".toLowerCase() = dotless i; Locale.ROOT ile "i" olmali
            expect(c, user("ALI.VELI@BINGOL.EDU.TR", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "I -> i (ROOT)");
            expect(c, user("ali.veli@bingol.edu.tr", u -> { }), Status.APPROVED, ApprovalMode.AUTO, "kucuk i");
            // noktali buyuk I ve noktasiz kucuk i ASCII harf degildir
            expect(c, user("ALİ.VELİ@bingol.edu.tr", u -> { }), Status.PENDING, null, "noktali I");
            expect(c, user("alı.veli@bingol.edu.tr", u -> { }), Status.PENDING, null, "noktasiz i");
        } finally {
            java.util.Locale.setDefault(old);
        }
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
