package edu.bingol.backend.moderation;

import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * YALNIZ duman betigi icin (varsayilan kapali): EVENT_COVER turunu sahte, geri alinabilir bir handler ile etkinlestirir
 * (hedef kimligi = sahibi olan kullanici kimligi; gizleme bellekte). Otomatik gizleme, onizleme, itiraz ve toplu karar
 * akislarini gercek medya turleri gelmeden uctan uca dogrulamak icindir. `app.moderation.smoke-handler=true` ile acilir.
 * Gercek EVENT_COVER handler'i (T10) eklenince bu bean kapali kalmalidir.
 */
@Component
@ConditionalOnProperty(name = "app.moderation.smoke-handler", havingValue = "true")
public class SmokeReportTargetHandler implements ReportTargetHandler {

    private final UserRepository users;
    private final Set<Long> hidden = ConcurrentHashMap.newKeySet();

    public SmokeReportTargetHandler(UserRepository users) {
        this.users = users;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.EVENT_COVER;
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
        hidden.add(targetId);
    }

    @Override
    public Optional<MediaPreview> preview(Long targetId) {
        return Optional.of(MediaPreview.image("/smoke/" + targetId + ".jpg", "/smoke/" + targetId + "-t.jpg", "image/jpeg"));
    }

    @Override
    public boolean reversible() {
        return true;
    }

    @Override
    public void unhide(Long targetId) {
        hidden.remove(targetId);
    }

    /** Duman betigi icin gozlem. */
    public boolean isHidden(Long targetId) {
        return hidden.contains(targetId);
    }
}
