package edu.bingol.backend.profile.privacy;

import java.util.List;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/** Kayitli tum {@link AvatarCleanup} kancalarini cagirir ve privacy satirini siler; hata yutulur. */
@Component
public class AvatarCleanups {

    private static final Logger log = LoggerFactory.getLogger(AvatarCleanups.class);

    private final ObjectProvider<AvatarCleanup> hooks;
    private final PrivacyService privacy;

    public AvatarCleanups(ObjectProvider<AvatarCleanup> hooks, PrivacyService privacy) {
        this.hooks = hooks;
        this.privacy = privacy;
    }

    public void run(Long userId, String... refs) {
        List<String> list = java.util.Arrays.stream(refs).filter(Objects::nonNull).toList();
        for (AvatarCleanup h : hooks.orderedStream().toList()) {
            try {
                h.cleanup(userId, list);
            } catch (RuntimeException e) {
                log.warn("avatar cleanup hook failed user={} hook={}: {}", userId, h.getClass().getSimpleName(),
                        e.toString());
            }
        }
        try {
            privacy.purge(userId);
        } catch (RuntimeException e) {
            log.warn("profile_privacy purge failed user={}: {}", userId, e.toString());
        }
    }
}
