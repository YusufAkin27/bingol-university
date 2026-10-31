package edu.bingol.backend.event;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.moderation.BlockService;
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
    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final BlockService blocks;

    public EventReportHandler(UserEventRepository events, @org.springframework.context.annotation.Lazy EventModerationService moderation,
                              CommunityRepository communities, CommunityMemberRepository members, BlockService blocks) {
        this.events = events;
        this.moderation = moderation;
        this.communities = communities;
        this.members = members;
        this.blocks = blocks;
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

    /**
     * Raporlayan etkinligi GOREBILIYORSA (T-057): yayinda (ACTIVE), bagli kulup ACTIVE ve ozel kulupse raporlayan
     * aktif uye, olusturanla engel iliskisi yok. Onay bekleyen/gizli/reddedilen etkinlik olmayanla ayni 404.
     */
    @Override
    public boolean exists(Long viewerId, Long targetId) {
        return events.findById(targetId).filter(e -> visibleTo(e, viewerId, communities, members, blocks)).isPresent();
    }

    /** Etkinlik/kapak icin ortak gorunurluk kurali. */
    static boolean visibleTo(UserEvent e, Long viewerId, CommunityRepository communities,
                             CommunityMemberRepository members, BlockService blocks) {
        if (e.getStatus() != UserEvent.Status.ACTIVE) {
            return false;
        }
        if (e.getCommunityId() != null) {
            Community c = communities.findById(e.getCommunityId()).orElse(null);
            if (c == null || c.getStatus() != Community.Status.ACTIVE) {
                return false;
            }
            if (c.getVisibility() == Community.Visibility.PRIVATE && viewerId != null
                    && !c.getOwnerId().equals(viewerId)
                    && members.findByCommunityIdAndUserId(c.getId(), viewerId).filter(CommunityMember::isActive).isEmpty()) {
                return false;
            }
        }
        return viewerId == null || e.getCreatedBy() == null || e.getCreatedBy().equals(viewerId)
                || !blocks.isBlocked(viewerId, e.getCreatedBy());
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
