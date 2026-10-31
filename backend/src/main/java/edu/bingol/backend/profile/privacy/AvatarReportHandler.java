package edu.bingol.backend.profile.privacy;

import edu.bingol.backend.moderation.BlockService;
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
    /** Gorunurluk denetimi (T-057): istege bagli; yoksa (elle kurulan testler) yalniz exists(id) kurali. */
    private AvatarVisibility visibility;
    private BlockService blocks;

    public AvatarReportHandler(UserRepository users, PrivacyService privacy) {
        this.users = users;
        this.privacy = privacy;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setVisibility(AvatarVisibility visibility, BlockService blocks) {
        this.visibility = visibility;
        this.blocks = blocks;
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

    /**
     * Raporlayan avatari GOREBILIYORSA (T-057): aktif hesap + avatar var + moderasyonla gizli degil + sahibi raporlayani
     * engellememis + avatar gizlilik kitlesi raporlayani kapsiyor (ONLY_ME avatar olmayanla ayni 404).
     */
    @Override
    public boolean exists(Long viewerId, Long targetId) {
        if (!exists(targetId)) {
            return false;
        }
        if (viewerId == null || viewerId.equals(targetId) || visibility == null || blocks == null) {
            return true;
        }
        if (blocks.hasBlocked(targetId, viewerId) || privacy.get(targetId).isAvatarHidden()) {
            return false;
        }
        return visibility.visibleOwners(viewerId, java.util.List.of(targetId),
                java.util.List.of(AvatarVisibility.Field.AVATAR)).get(AvatarVisibility.Field.AVATAR).contains(targetId);
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
