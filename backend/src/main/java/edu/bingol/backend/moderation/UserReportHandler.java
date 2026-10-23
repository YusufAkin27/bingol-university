package edu.bingol.backend.moderation;

import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.springframework.stereotype.Component;

/** USER hedefi: "gizle" = hesabi askiya al. */
@Component
public class UserReportHandler implements ReportTargetHandler {

    private final UserRepository users;
    private final UserModerationService moderation;

    public UserReportHandler(UserRepository users, UserModerationService moderation) {
        this.users = users;
        this.moderation = moderation;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.USER;
    }

    @Override
    public boolean exists(Long targetId) {
        return users.existsById(targetId);
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
