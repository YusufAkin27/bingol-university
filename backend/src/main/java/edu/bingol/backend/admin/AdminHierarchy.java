package edu.bingol.backend.admin;

import edu.bingol.backend.admin.rbac.AdminPermissionContext;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import org.springframework.http.HttpStatus;

/**
 * Yonetici hiyerarsisi (T-014): `users.write` sahibi bir profil (MODERATOR) baska bir YONETICI hesabina (oturum
 * kapatma, sifre sifirlama, profil/cihaz mudahalesi) dokunamaz; yonetici hesabina yalniz FULL mudahale eder. Kural tek
 * yerdedir; kullanici yazma servisleri (`Targets`, hesap islemleri) buradan gecer. Istek disinda (birim testi,
 * zamanlayici) baglam yoktur => kisitlama yok (PermissionAwareMasking ile ayni kural).
 */
public final class AdminHierarchy {

    private AdminHierarchy() {}

    /** Hedef ADMIN ise ve istegi yapan FULL degilse 403 ADMIN_TARGET_FORBIDDEN. */
    public static void requireManageable(User target) {
        if (target == null || target.getRole() != Role.ADMIN) {
            return;
        }
        AdminPermissionContext ctx = AdminPermissionContext.current();
        if (ctx != null && ctx.profile() != AdminProfile.FULL) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ADMIN_TARGET_FORBIDDEN",
                    "Yönetici hesabına yalnızca FULL yönetici müdahale edebilir.");
        }
    }
}
