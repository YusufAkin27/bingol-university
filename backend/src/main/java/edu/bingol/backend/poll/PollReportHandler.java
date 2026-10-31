package edu.bingol.backend.poll;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Moderasyon SPI: POLL hedefi (T-057). Raporlayan anketi GOREBILIYORSA raporlanabilir (taslak/iptal edilmis, uyesi
 * olmadigi kulup anketi, hedef kitlesine uymadigi anket olmayanla ayni 404). "Gizle" = anket (secenek, secmen kaydi, oylar)
 * silinir; geri alinamaz, yalniz yonetici karariyla.
 */
@Component
public class PollReportHandler implements ReportTargetHandler {

    private final PollRepository polls;
    private final PollAccess access;
    private final UserRepository users;
    private final PollVoteRepository votes;
    private final PollBallotRepository ballots;
    private final PollOptionRepository options;

    public PollReportHandler(PollRepository polls, PollAccess access, UserRepository users, PollVoteRepository votes,
                             PollBallotRepository ballots, PollOptionRepository options) {
        this.polls = polls;
        this.access = access;
        this.users = users;
        this.votes = votes;
        this.ballots = ballots;
        this.options = options;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.POLL;
    }

    @Override
    public boolean exists(Long targetId) {
        return polls.existsById(targetId);
    }

    @Override
    public boolean exists(Long viewerId, Long targetId) {
        Poll p = polls.findById(targetId).orElse(null);
        if (p == null || p.getStatus() == Poll.Status.DRAFT || p.getStatus() == Poll.Status.CANCELLED) {
            return false;
        }
        if (viewerId == null) {
            return true;
        }
        return access.canView(p, new Actor(viewerId, false), access.memberCommunityIds(viewerId),
                users.findById(viewerId).orElse(null));
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return polls.findById(targetId).map(Poll::getCreatedBy);
    }

    @Override
    @Transactional
    public void hide(Long targetId) {
        polls.findById(targetId).ifPresent(p -> {
            votes.deleteByPollId(targetId);
            ballots.deleteByPollId(targetId);
            options.deleteByPollId(targetId);
            polls.delete(p);
        });
    }
}
