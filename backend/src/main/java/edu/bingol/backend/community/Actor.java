package edu.bingol.backend.community;

import edu.bingol.backend.common.CurrentUser;
import java.util.Set;

/**
 * Istegi yapan kisi: kullanici id'si + sistem yoneticisi mi + (kullanici API'sinden gelen yonetici icin) yonetici
 * izinleri. Servisler SecurityContext'e degil buna bakar (test edilebilirlik).
 *
 * <p>Sistem yoneticisi mudahalesi artik "rol ADMIN" degil, ILGILI IZINdir ({@link #systemAdmin(String)}): VIEWER profili
 * ROLE_ADMIN tasir ama kulup/etkinlik/anket silemez. {@code adminPerms == null} = izin kisiti yok (yonetici API'si
 * zaten AdminPermissionInterceptor'dan gecmistir; {@code new Actor(id, true)} bu anlama gelir).
 */
public record Actor(Long id, boolean admin, Set<String> adminPerms) {

    /** Yonetici API'si / dahili cagrilar: izin kisiti yok (admin ise her sey). */
    public Actor(Long id, boolean admin) {
        this(id, admin, null);
    }

    public static Actor current() {
        boolean admin = CurrentUser.isAdmin();
        return new Actor(CurrentUser.id(), admin, admin ? CurrentUser.adminPermissions() : null);
    }

    /** Sistem yoneticisi bu IZINle mudahale edebilir mi (izin kisiti yoksa admin yeter). */
    public boolean systemAdmin(String perm) {
        return admin && (adminPerms == null || adminPerms.contains(perm));
    }

    /** Kullanici API'sinden gelen yonetici mi (denetim kaydi gerektirir; yonetici API'si kendi denetimini yazar). */
    public boolean viaUserApi() {
        return admin && adminPerms != null;
    }
}
