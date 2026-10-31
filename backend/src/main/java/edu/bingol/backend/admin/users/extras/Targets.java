package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import org.springframework.http.HttpStatus;

/** Hedef kullanici arama + sebep dogrulama yardimcilari (paket ici). */
final class Targets {

    private Targets() {}

    static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
    }

    /** Var olan hesap (silinmis/anonimlestirilmis dahil; okuma uclari icin). */
    static User existing(UserRepository users, Long id) {
        return users.findById(id).orElseThrow(Targets::notFound);
    }

    /** Silinmemis hesap (yazma uclari icin). */
    static User active(UserRepository users, Long id) {
        return users.findById(id).filter(u -> u.getStatus() != UserStatus.DELETED).orElseThrow(Targets::notFound);
    }

    /** Silinmemis hesap + hiyerarsi (T-014): hedef yonetici ise yalniz FULL mudahale eder; yazma uclari icin. */
    static User manageable(UserRepository users, Long id) {
        User u = active(users, id);
        edu.bingol.backend.admin.AdminHierarchy.requireManageable(u);
        return u;
    }

    /** Sebep en az `min` karakter degilse 400 REASON_REQUIRED; kirpilmis sebebi doner. */
    static String reason(String reason, int min) {
        String r = reason == null ? "" : reason.strip();
        if (r.length() < min) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + min + " karakter).", String.valueOf(min));
        }
        return r;
    }
}
