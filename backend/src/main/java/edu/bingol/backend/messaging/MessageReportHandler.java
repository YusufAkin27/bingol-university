package edu.bingol.backend.messaging;

import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.time.Instant;
import java.util.Optional;
import org.springframework.stereotype.Component;

/** MESSAGE hedefi: "gizle" = yumusak silme (`hiddenAt`); API icerik yerine "Bu mesaj kaldırıldı" doner. */
@Component
public class MessageReportHandler implements ReportTargetHandler {

    private final MessageRepository messages;

    public MessageReportHandler(MessageRepository messages) {
        this.messages = messages;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.MESSAGE;
    }

    @Override
    public boolean exists(Long targetId) {
        return messages.existsById(targetId);
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return messages.findById(targetId).map(Message::getSenderId);
    }

    @Override
    public void hide(Long targetId) {
        messages.hide(targetId, Instant.now());
    }
}
