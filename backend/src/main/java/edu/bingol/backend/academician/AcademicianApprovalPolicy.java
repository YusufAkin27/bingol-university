package edu.bingol.backend.academician;

import edu.bingol.backend.academician.Academician.ApprovalMode;
import edu.bingol.backend.academician.Academician.Status;
import edu.bingol.backend.academician.AcademicianProperties.AutoApprove;
import edu.bingol.backend.user.User;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Akademisyen otomatik onay kurali (saf fonksiyon, tablo testlidir). STAFF_PATTERN iken YALNIZ su dort kosulun hepsi
 * varsa APPROVED/AUTO, aksi halde PENDING (yonetici onayi):
 * 1) e-posta kodla dogrulanmis (emailVerified, ertelenmis dogrulama degil, Apple gizli adresi degil);
 * 2) alan adi tam olarak bingol.edu.tr (alt alan adi yok);
 * 3) yerel kisim harf icerir ve 6-12 haneli ogrenci numarasi degildir;
 * 4) hesapta ogrenci isareti yok (grade ve classYear bos).
 */
public final class AcademicianApprovalPolicy {

    static final String STAFF_DOMAIN = "bingol.edu.tr";
    private static final Pattern STUDENT_NUMBER = Pattern.compile("[0-9]{6,12}");

    public record Decision(Status status, ApprovalMode mode) {}

    private AcademicianApprovalPolicy() {}

    public static Decision decide(AutoApprove config, User u) {
        if (config == AutoApprove.STAFF_PATTERN && qualifies(u)) {
            return new Decision(Status.APPROVED, ApprovalMode.AUTO);
        }
        return new Decision(Status.PENDING, null);
    }

    static boolean qualifies(User u) {
        if (u == null || u.getEmail() == null) {
            return false;
        }
        if (!u.isEmailVerified() || u.isVerificationDeferred() || u.isEmailRelay()) {
            return false;
        }
        String email = u.getEmail().trim().toLowerCase(Locale.ROOT);
        int at = email.lastIndexOf('@');
        if (at <= 0 || !email.substring(at + 1).equals(STAFF_DOMAIN)) {
            return false;
        }
        String local = email.substring(0, at);
        boolean hasLetter = local.chars().anyMatch(Character::isLetter);
        if (!hasLetter || STUDENT_NUMBER.matcher(local).matches()) {
            return false;
        }
        return u.getGrade() == null && u.getClassYear() == null;
    }

    /** Dizin icin: bingol.edu.tr adresinin yerel kismi 6-12 hane ise ogrenci numarasi, degilse null. */
    public static String studentNo(String email) {
        if (email == null) {
            return null;
        }
        String e = email.trim().toLowerCase(Locale.ROOT);
        int at = e.lastIndexOf('@');
        if (at <= 0 || !e.substring(at + 1).equals(STAFF_DOMAIN)) {
            return null;
        }
        String local = e.substring(0, at);
        return STUDENT_NUMBER.matcher(local).matches() ? local : null;
    }
}
