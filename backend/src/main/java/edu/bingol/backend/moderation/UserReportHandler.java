package edu.bingol.backend.moderation;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.springframework.stereotype.Component;

/** USER hedefi: "gizle" = hesabi askiya al. */
@Component
public class UserReportHandler implements ReportTargetHandler {

    private final UserRepository users;
    private final UserModerationService moderation;
    private final BlockService blocks;

    public UserReportHandler(UserRepository users, UserModerationService moderation, BlockService blocks) {
        this.users = users;
        this.moderation = moderation;
        this.blocks = blocks;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.USER;
    }

    @Override
    public boolean exists(Long targetId) {
        return users.existsById(targetId);
    }

    /**
     * Raporlayan kullaniciyi GOREBILIYORSA (T-057): hesap aktif (silinmis/askidaki kimlik olmayanla ayni 404) ve hedef
     * raporlayani engellememis. Raporlayanin kendi engelledigi kisiyi raporlamasi serbesttir (engelle + raporla akisi).
     */
    @Override
    public boolean exists(Long viewerId, Long targetId) {
        return users.findById(targetId).filter(User::isActive)
                .filter(u -> viewerId == null || viewerId.equals(targetId) || !blocks.hasBlocked(targetId, viewerId))
                .isPresent();
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return Optional.of(targetId);
    }

    @Override
    public void hide(Long targetId) {
        moderation.suspend(targetId, "Rapor sonucu askıya alındı");
    }
}
