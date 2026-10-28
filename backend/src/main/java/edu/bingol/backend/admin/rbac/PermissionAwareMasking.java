package edu.bingol.backend.admin.rbac;

/**
 * Maskeli profiller (SUPPORT, VIEWER: `users.pii` yok) icin kisisel alan maskeleme. Istek baglami yoksa (birim testi,
 * zamanlayici) ya da profil `users.pii` iznine sahipse deger oldugu gibi doner.
 */
public final class PermissionAwareMasking {

    private PermissionAwareMasking() {}

    /** Gecerli yonetici kisisel veriyi maskesiz gorebilir mi. */
    public static boolean canSeePii() {
        AdminPermissionContext c = AdminPermissionContext.current();
        return c == null || c.can(PermissionMatrix.USERS_PII);
    }

    /** E-postayi gerekiyorsa maskeler: "a***@bingol.edu.tr". */
    public static String email(String email) {
        return canSeePii() ? email : maskEmail(email);
    }

    /** IP/cihaz gibi serbest degerleri gerekiyorsa tamamen gizler. */
    public static String opaque(String value) {
        return canSeePii() || value == null ? value : "***";
    }

    /** Saf maskeleme (bagimsiz testlenir): ilk karakter + *** + @alan. */
    public static String maskEmail(String email) {
        if (email == null || email.isEmpty()) {
            return email;
        }
        int at = email.indexOf('@');
        if (at <= 0) {
            return "***";
        }
        return email.charAt(0) + "***" + email.substring(at);
    }
}
