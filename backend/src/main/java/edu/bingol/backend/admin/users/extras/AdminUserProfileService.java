package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.admin.AdminGuardPolicy;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.ProfilePatch;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.ProfilePatchResult;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.naming.DisplayNamePolicy;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici profil mudahalesi: avatar/biyografi temizleme ve gorunen adi duzeltme. Uygunsuz ifade filtresi YONETICI
 * duzenlemesinde atlanir (ContentGuard cagrilmaz); gorunen ad yine de bicim kurallarindan (DisplayNamePolicy) gecer.
 * Degisiklik olursa kullaniciya kendi dilinde bildirim gider.
 */
@Service
public class AdminUserProfileService {

    private static final Logger log = LoggerFactory.getLogger(AdminUserProfileService.class);

    private final UserRepository users;
    private final ProfileService profiles;
    private final NotificationService notifications;

    public AdminUserProfileService(UserRepository users, ProfileService profiles, NotificationService notifications) {
        this.users = users;
        this.profiles = profiles;
        this.notifications = notifications;
    }

    @Transactional
    public ProfilePatchResult patch(Long targetId, ProfilePatch p, String reason) {
        Targets.reason(reason, AdminGuardPolicy.DEFAULT_MIN_REASON);
        boolean wantAvatar = Boolean.TRUE.equals(p.clearAvatar());
        boolean wantBio = Boolean.TRUE.equals(p.clearBio());
        boolean wantName = p.displayName() != null;
        if (!wantAvatar && !wantBio && !wantName) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PROFILE_PATCH_EMPTY", "Değiştirilecek alan belirtilmedi.");
        }
        User u = Targets.manageable(users, targetId);

        // Once dogrulama (hicbir alan yarim kalmasin): ad gecersizse 400 ve hicbir sey degismez.
        String newName = wantName ? DisplayNamePolicy.normalize(p.displayName(), u.getRole() == Role.ADMIN) : null;

        boolean avatarCleared = wantAvatar && u.getAvatarUrl() != null;
        boolean bioCleared = wantBio && u.getBio() != null;
        boolean nameChanged = wantName && !newName.equals(u.getDisplayName());
        if (bioCleared) {
            u.setBio(null);
        }
        if (nameChanged) {
            u.setDisplayName(newName);
        }
        if (bioCleared || nameChanged) {
            users.save(u);
        }
        if (avatarCleared) {
            profiles.removeAvatar(targetId); // medya hattindan serbest birakir (media.release)
        }
        ProfilePatchResult res = new ProfilePatchResult(avatarCleared, bioCleared, nameChanged);
        if (res.changed()) {
            notifyUser(targetId);
        }
        return res;
    }

    /** Bildirim hatasi islemi bozmaz (servis sozlesmesi: gonderim cagirana exception sizdirmaz). */
    private void notifyUser(Long userId) {
        try {
            notifications.sendLocalized(userId, NotificationType.SYSTEM, "notif.profile.moderated.title",
                    "notif.profile.moderated.body", null, null);
        } catch (RuntimeException e) {
            log.warn("profil mudahalesi bildirimi gonderilemedi userId={}: {}", userId, e.toString());
        }
    }
}
