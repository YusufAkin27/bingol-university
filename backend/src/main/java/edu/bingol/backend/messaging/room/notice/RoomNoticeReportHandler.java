package edu.bingol.backend.messaging.room.notice;

import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.time.Instant;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** BOARD_NOTICE hedefi: raporlayan odanin aktif uyesi olmali; gizleme geri alinabilir yumusak gizlemedir. */
@Component
public class RoomNoticeReportHandler implements ReportTargetHandler {

    private final RoomNoticeRepository notices;
    private final ConversationMemberRepository members;

    public RoomNoticeReportHandler(RoomNoticeRepository notices, ConversationMemberRepository members) {
        this.notices = notices;
        this.members = members;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.BOARD_NOTICE;
    }

    @Override
    public boolean exists(Long targetId) {
        return notices.findById(targetId).filter(n -> n.getDeletedAt() == null).isPresent();
    }

    @Override
    public boolean exists(Long viewerId, Long targetId) {
        return notices.findById(targetId).filter(RoomNotice::isLive)
                .filter(n -> viewerId != null && members
                        .findByConversationIdAndUserIdAndLeftAtIsNull(n.getConversationId(), viewerId).isPresent())
                .isPresent();
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return notices.findById(targetId).map(RoomNotice::getAuthorId);
    }

    @Override
    @Transactional
    public void hide(Long targetId) {
        notices.findById(targetId).ifPresent(n -> {
            if (n.getHiddenAt() == null) {
                n.setHiddenAt(Instant.now());
                n.setPinned(false);
                notices.save(n);
            }
        });
    }

    @Override
    public boolean reversible() {
        return true;
    }

    @Override
    @Transactional
    public void unhide(Long targetId) {
        notices.findById(targetId).ifPresent(n -> {
            if (n.getHiddenAt() != null) {
                n.setHiddenAt(null);
                notices.save(n);
            }
        });
    }
}
