package edu.bingol.backend.profile.privacy;

import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * USER_AVATAR hedefi (targetId = avatar sahibinin kullanici id'si). "Gizle" = hesabi askiya almadan yalnizca
 * avatari gizler (profile_privacy.avatar_hidden); dosya silinmez, kanit olarak kalir.
 */
@Component
public class AvatarReportHandler implements ReportTargetHandler {

    private final UserRepository users;
    private final PrivacyService privacy;

    public AvatarReportHandler(UserRepository users, PrivacyService privacy) {
        this.users = users;
        this.privacy = privacy;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.USER_AVATAR;
    }

    /** Yalniz aktif ve avatari olan hesap raporlanabilir (silinmis/askidaki hesabin avatari zaten gorunmez). */
    @Override
    public boolean exists(Long targetId) {
        return users.findById(targetId).filter(User::isActive).map(u -> u.getAvatarUrl() != null).orElse(false);
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return Optional.of(targetId);
    }

    @Override
    public void hide(Long targetId) {
        privacy.setAvatarHidden(targetId, true);
    }
}
