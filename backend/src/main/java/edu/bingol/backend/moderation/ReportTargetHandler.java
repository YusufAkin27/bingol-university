package edu.bingol.backend.moderation;

import java.util.Optional;

/**
 * Raporlanabilir bir icerik turunun moderasyon adaptoru. Mesajlasma, topluluk ve etkinlik modulleri kendi
 * turleri icin bunu bean olarak uygular; moderasyon servisi tum handler'lari otomatik toplar.
 */
public interface ReportTargetHandler {

    ReportTargetType type();

    boolean exists(Long targetId);

    /** Icerigin sahibi (uyari/askiya alma icin); bilinmiyorsa bos. */
    Optional<Long> ownerId(Long targetId);

    /** Icerigi gizle/kaldir (yumusak silme). Raporu "HIDE" ile cozunce cagrilir. */
    void hide(Long targetId);
}
