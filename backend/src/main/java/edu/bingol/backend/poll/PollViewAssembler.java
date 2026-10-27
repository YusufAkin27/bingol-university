package edu.bingol.backend.poll;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.poll.PollDtos.Audience;
import edu.bingol.backend.poll.PollDtos.CreatedBy;
import edu.bingol.backend.poll.PollDtos.MyVote;
import edu.bingol.backend.poll.PollDtos.OptionView;
import edu.bingol.backend.poll.PollDtos.PollView;
import edu.bingol.backend.poll.PollDtos.Result;
import edu.bingol.backend.poll.PollDtos.Turnout;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/**
 * Anket entity'lerini API gorunumune cevirir (toplu: secenek/oy/kullanici/kulup sorgulari anket basina degil topluca).
 * Sonuc gorunurluk kurali burada uygulanir; kim ne oy verdi bilgisi HICBIR yerde uretilmez (yalniz kullanicinin kendi oyu).
 */
@Component
public class PollViewAssembler {

    private final PollOptionRepository options;
    private final PollBallotRepository ballots;
    private final PollVoteRepository votes;
    private final UserRepository users;
    private final CommunityRepository communities;
    private final MenuRepository menus;
    private final PollAccess access;
    private final I18n i18n;
    private final Clock clock;

    public PollViewAssembler(PollOptionRepository options, PollBallotRepository ballots, PollVoteRepository votes,
                             UserRepository users, CommunityRepository communities, MenuRepository menus,
                             PollAccess access, I18n i18n, Clock clock) {
        this.options = options;
        this.ballots = ballots;
        this.votes = votes;
        this.users = users;
        this.communities = communities;
        this.menus = menus;
        this.access = access;
        this.i18n = i18n;
        this.clock = clock;
    }

    public PollView view(Poll p, Actor actor, boolean adminView) {
        return views(List.of(p), actor, adminView).get(0);
    }

    /** @param adminView true ise sonuclar her zaman gorunur ve yonetim yetkisi var sayilir (yonetici uclari) */
    public List<PollView> views(List<Poll> polls, Actor actor, boolean adminView) {
        if (polls.isEmpty()) {
            return List.of();
        }
        Instant now = clock.instant();
        List<Long> ids = polls.stream().map(Poll::getId).toList();
        Map<Long, List<PollOption>> optsByPoll = options.findByPollIdInOrderByPollIdAscPositionAsc(ids).stream()
                .collect(Collectors.groupingBy(PollOption::getPollId));
        Map<Long, PollBallot> myBallots = new HashMap<>();
        Map<Long, List<PollVote>> myVotes = new HashMap<>();
        Set<Long> memberCids = Set.of();
        User me = null;
        if (actor != null) {
            ballots.findByUserIdAndPollIdIn(actor.id(), ids).forEach(b -> myBallots.put(b.getPollId(), b));
            votes.findByUserIdAndPollIdIn(actor.id(), ids).stream()
                    .sorted(Comparator.comparingInt(PollVote::getChoiceRank))
                    .forEach(v -> myVotes.computeIfAbsent(v.getPollId(), k -> new ArrayList<>()).add(v));
            memberCids = access.memberCommunityIds(actor.id());
            me = users.findById(actor.id()).orElse(null);
        }
        Set<Long> creatorIds = polls.stream().map(Poll::getCreatedBy).filter(java.util.Objects::nonNull).collect(Collectors.toSet());
        Map<Long, String> creatorNames = new HashMap<>();
        if (!creatorIds.isEmpty()) {
            users.findAllById(creatorIds).forEach(u -> creatorNames.put(u.getId(), u.getDisplayName()));
        }
        Set<Long> cids = polls.stream().map(Poll::getCommunityId).filter(java.util.Objects::nonNull).collect(Collectors.toSet());
        Map<Long, String> communityNames = new HashMap<>();
        if (!cids.isEmpty()) {
            communities.findAllById(cids).forEach(c -> communityNames.put(c.getId(), c.getName()));
        }
        List<PollView> out = new ArrayList<>(polls.size());
        for (Poll p : polls) {
            out.add(one(p, optsByPoll.getOrDefault(p.getId(), List.of()), myBallots.get(p.getId()),
                    myVotes.getOrDefault(p.getId(), List.of()), actor, me, memberCids, creatorNames, communityNames,
                    adminView, now));
        }
        return out;
    }

    private PollView one(Poll p, List<PollOption> opts, PollBallot ballot, List<PollVote> mine, Actor actor, User me,
                         Set<Long> memberCids, Map<Long, String> creatorNames, Map<Long, String> communityNames,
                         boolean adminView, Instant now) {
        boolean closed = p.isClosedAt(now);
        String state = state(p, now);
        boolean voted = ballot != null;
        boolean manage = adminView || (actor != null && access.canManage(p, actor));
        String reason = blockReason(p, state, me, memberCids, voted);
        boolean visible = adminView || switch (p.getShowResults()) {
            case ALWAYS -> true;
            case AFTER_VOTE -> voted || closed;
            case AFTER_CLOSE -> closed;
        };
        MyVote my = null;
        if (voted) {
            List<Long> optionIds = mine.stream().map(PollVote::getOptionId).toList();
            Integer rating = null;
            if (p.getType() == Poll.Type.RATING && !optionIds.isEmpty()) {
                rating = opts.stream().filter(o -> o.getId().equals(optionIds.get(0))).map(o -> (int) o.getPosition())
                        .findFirst().orElse(null);
            }
            my = new MyVote(optionIds, rating, at(ballot.getUpdatedAt()));
        }
        List<Result> results = null;
        Integer total = null;
        Turnout turnout = null;
        Double average = null;
        Integer ratingCount = null;
        if (visible) {
            int voters = p.getVoterCount();
            total = voters;
            results = opts.stream().map(o -> new Result(o.getId(), o.getVoteCount(), percent(o.getVoteCount(), voters),
                    p.getType() == Poll.Type.RANKED ? o.getRankScore() : null)).toList();
            Integer eligible = access.eligibleCount(p);
            turnout = new Turnout(voters, eligible, eligible == null || eligible == 0 ? null : percent(voters, eligible));
            if (p.getType() == Poll.Type.RATING) {
                ratingCount = voters;
                long sum = opts.stream().mapToLong(o -> (long) o.getPosition() * o.getVoteCount()).sum();
                average = voters == 0 ? null : round1((double) sum / voters);
            }
        }
        String title = p.getScope() == Poll.Scope.MENU && p.getCreatedBy() == null ? i18n.current("poll.menu.title") : p.getTitle();
        List<String> menuItems = null;
        if (p.getScope() == Poll.Scope.MENU && p.getMenuDate() != null) {
            menuItems = menus.findByMenuDate(p.getMenuDate()).map(PollViewAssembler::items).orElse(List.of());
        }
        Audience aud = p.hasAudience() ? new Audience(p.getAudienceFaculty(), p.getAudienceDepartment(), p.getAudienceGrade()) : null;
        CreatedBy cb = p.getCreatedBy() == null ? null : new CreatedBy(p.getCreatedBy(), creatorNames.getOrDefault(p.getCreatedBy(), null));
        return new PollView(p.getId(), title, p.getDescription(), p.getType().name(), p.getScope().name(),
                p.getCommunityId(), p.getCommunityId() == null ? null : communityNames.get(p.getCommunityId()), p.getMenuDate(),
                menuItems, opts.stream().map(o -> new OptionView(o.getId(), o.getText(), o.getPosition())).toList(),
                p.getMaxChoices(), p.isAnonymous(), p.isAllowChangeVote(), p.getShowResults().name(), p.isNotify(),
                at(p.getOpensAt()), at(p.getClosesAt()), aud, p.getStatus().name(), state, at(p.getCreatedAt()),
                at(p.getClosedAt()), cb, reason == null, reason, manage, my, visible, results, total, turnout, average,
                ratingCount);
    }

    /** SCHEDULED/OPEN/CLOSED/CANCELLED/DRAFT (sure dolmus ama isleyici henuz calismamissa CLOSED). */
    static String state(Poll p, Instant now) {
        return switch (p.getStatus()) {
            case DRAFT -> "DRAFT";
            case CANCELLED -> "CANCELLED";
            case CLOSED -> "CLOSED";
            case OPEN -> p.isExpired(now) ? "CLOSED" : p.getOpensAt().isAfter(now) ? "SCHEDULED" : "OPEN";
        };
    }

    private String blockReason(Poll p, String state, User me, Set<Long> memberCids, boolean voted) {
        return switch (state) {
            case "DRAFT", "SCHEDULED" -> "NOT_OPEN";
            case "CLOSED", "CANCELLED" -> "CLOSED";
            default -> !access.eligible(p, me, memberCids) ? "NOT_ELIGIBLE"
                    : voted && !p.isAllowChangeVote() ? "ALREADY_VOTED" : null;
        };
    }

    static List<String> items(MenuDay d) {
        return Arrays.stream(d.getItems().split("\\R")).map(String::trim).filter(s -> !s.isEmpty()).toList();
    }

    static double percent(int part, int whole) {
        return whole <= 0 ? 0.0 : round1(part * 100.0 / whole);
    }

    static double round1(double v) {
        return Math.round(v * 10.0) / 10.0;
    }

    static OffsetDateTime at(Instant i) {
        return i == null ? null : i.atZone(PollAccess.ZONE).toOffsetDateTime();
    }

    /** Disaridan: yalniz kimlik listesi gerekirse. */
    static Set<Long> idsOf(Collection<Poll> polls) {
        return polls.stream().map(Poll::getId).collect(Collectors.toCollection(HashSet::new));
    }
}
