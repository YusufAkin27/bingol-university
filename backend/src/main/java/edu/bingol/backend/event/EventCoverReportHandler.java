package edu.bingol.backend.event;

import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.Optional;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moderasyon SPI: EVENT_COVER (hedef kimligi = etkinlik kimligi, T-057). "Gizle" = kapak gorseli kaldirilir (etkinlik
 * yerinde kalir); geri alinamaz, yalniz yonetici karariyla. `app.moderation.smoke-handler=true` iken duman betigi
 * handler'i bu turu ustlendiginden bu bean kapali kalir.
 */
@Component
@ConditionalOnProperty(name = "app.moderation.smoke-handler", havingValue = "false", matchIfMissing = true)
public class EventCoverReportHandler implements ReportTargetHandler {

    private final UserEventRepository events;
    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final BlockService blocks;
    private final MediaService media;

    public EventCoverReportHandler(UserEventRepository events, CommunityRepository communities,
                                   CommunityMemberRepository members, BlockService blocks, MediaService media) {
        this.events = events;
        this.communities = communities;
        this.members = members;
        this.blocks = blocks;
        this.media = media;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.EVENT_COVER;
    }

    @Override
    public boolean exists(Long targetId) {
        return events.findById(targetId).filter(e -> e.getCoverUrl() != null).isPresent();
    }

    @Override
    public boolean exists(Long viewerId, Long targetId) {
        return events.findById(targetId).filter(e -> e.getCoverUrl() != null)
                .filter(e -> EventReportHandler.visibleTo(e, viewerId, communities, members, blocks)).isPresent();
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return events.findById(targetId).map(UserEvent::getCreatedBy);
    }

    @Override
    @Transactional
    public void hide(Long targetId) {
        events.findById(targetId).ifPresent(e -> {
            String cover = e.getCoverUrl();
            if (cover == null) {
                return;
            }
            e.setCoverUrl(null);
            events.save(e);
            media.release(cover);
        });
    }
}
