package edu.bingol.backend.event;

import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Moderasyon SPI: EVENT hedefi. "Gizle" = durumu HIDDEN (listeden ve aramadan kalkar). */
@Component
public class EventReportHandler implements ReportTargetHandler {

    private final UserEventRepository events;

    public EventReportHandler(UserEventRepository events) {
        this.events = events;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.EVENT;
    }

    @Override
    public boolean exists(Long targetId) {
        return events.findById(targetId).filter(e -> e.getStatus() != UserEvent.Status.HIDDEN).isPresent();
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return events.findById(targetId).map(UserEvent::getCreatedBy);
    }

    @Override
    @Transactional
    public void hide(Long targetId) {
        events.findById(targetId).ifPresent(e -> {
            e.setStatus(UserEvent.Status.HIDDEN);
            events.save(e);
        });
    }
}
