package edu.bingol.backend.event;

import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Moderasyon SPI: EVENT hedefi. "Gizle" = ACTIVE -> HIDDEN (listeden ve aramadan kalkar), geri alinabilir (itiraz/reddedilen rapor). */
@Component
public class EventReportHandler implements ReportTargetHandler {

    private final UserEventRepository events;
    private final EventModerationService moderation;

    public EventReportHandler(UserEventRepository events, @org.springframework.context.annotation.Lazy EventModerationService moderation) {
        this.events = events;
        this.moderation = moderation;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.EVENT;
    }

    @Override
    public boolean exists(Long targetId) {
        // Gizli etkinlik de "var"dir: geri alinabilir tur (itiraz/rapor reddi unhide cagirir).
        return events.existsById(targetId);
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return events.findById(targetId).map(UserEvent::getCreatedBy);
    }

    /** ACTIVE -> HIDDEN (gecmise REPORT_HIDE olarak yazilir); onay bekleyen/iptal/reddedilenler degismez. */
    @Override
    @Transactional
    public void hide(Long targetId) {
        moderation.hideForReport(targetId, true);
    }

    @Override
    public boolean reversible() {
        return true;
    }

    @Override
    @Transactional
    public void unhide(Long targetId) {
        moderation.hideForReport(targetId, false);
    }
}
