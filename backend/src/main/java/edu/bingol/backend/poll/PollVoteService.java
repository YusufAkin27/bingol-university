package edu.bingol.backend.poll;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.poll.PollDtos.PollView;
import edu.bingol.backend.poll.PollDtos.VoteRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Oy verme/geri cekme. Yaris guvenligi: anket satiri PESSIMISTIC_WRITE ile kilitlenir (bir ankette oylar siraya girer),
 * sayaclar atomik UPDATE ile artar/azalir, (poll_id,user_id) tekillik kisitlari son savunmadir. Idempotent: ayni oy tekrar
 * gonderilirse degisiklik olmaz.
 */
@Service
public class PollVoteService {

    private final PollRepository polls;
    private final PollOptionRepository options;
    private final PollBallotRepository ballots;
    private final PollVoteRepository votes;
    private final UserRepository users;
    private final PollAccess access;
    private final PollViewAssembler assembler;
    private final Clock clock;
    private final TransactionTemplate tx;

    public PollVoteService(PollRepository polls, PollOptionRepository options, PollBallotRepository ballots,
                           PollVoteRepository votes, UserRepository users, PollAccess access, PollViewAssembler assembler,
                           Clock clock, PlatformTransactionManager txManager) {
        this.polls = polls;
        this.options = options;
        this.ballots = ballots;
        this.votes = votes;
        this.users = users;
        this.access = access;
        this.assembler = assembler;
        this.clock = clock;
        this.tx = new TransactionTemplate(txManager);
    }

    /**
     * Oy ver. Kritik bolum kisa tutulur (yuk testi bulgusu: 300 es zamanli oy, anket satir kilidini ~10 ms'lik islemlerle
     * siraya sokuyor, bekleyen oylar Hikari baglantilarini tutup havuzu dolduruyordu). Kural denetimi ve secenek cozumleme
     * KILITSIZ yapilir; satir kilidi yalniz yazma icin (ballot + oy + sayac) alinir ve gorunum kilit birakildiktan sonra kurulur.
     * Anket kilit beklerken degistiyse (updatedAt farkli) hazirlik kilit icinde yeniden yapilir.
     */
    public PollView vote(Actor actor, Long pollId, VoteRequest req) {
        Poll pre = polls.findById(pollId).orElseThrow(PollService::notFound);
        List<PollOption> opts = options.findByPollIdOrderByPositionAsc(pollId);
        List<Long> chosen = prepare(pre, opts, actor, req, clock.instant());
        tx.executeWithoutResult(s -> {
            Poll p = polls.lockById(pollId).orElseThrow(PollService::notFound);
            Instant now = clock.instant();
            checkOpen(p, actor, now);
            List<Long> ids = p.getUpdatedAt().equals(pre.getUpdatedAt())
                    ? chosen : prepare(p, options.findByPollIdOrderByPositionAsc(pollId), actor, req, now);
            write(p, actor, ids, now);
        });
        return assembler.view(polls.findById(pollId).orElseThrow(), actor, false);
    }

    /** Acik mi, hak var mi, istek gecerli mi (kilit gerektirmez); secilen secenek kimliklerini doner. */
    private List<Long> prepare(Poll p, List<PollOption> opts, Actor actor, VoteRequest req, Instant now) {
        checkOpen(p, actor, now);
        Set<Long> cids = access.memberCommunityIds(actor.id());
        User me = users.findById(actor.id()).orElse(null);
        if (!access.eligible(p, me, cids)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "POLL_NOT_ELIGIBLE", "Bu ankete katılma hakkınız yok.");
        }
        return parse(p, opts, req);
    }

    /** Kilit altinda: ballot, oy satirlari ve atomik sayaclar (idempotent: ayni oy degisiklik yapmaz). */
    private void write(Poll p, Actor actor, List<Long> chosen, Instant now) {
        Long pollId = p.getId();
        PollBallot ballot = ballots.findByPollIdAndUserId(pollId, actor.id()).orElse(null);
        if (ballot != null) {
            List<Long> existing = votes.findByPollIdAndUserIdOrderByChoiceRankAsc(pollId, actor.id()).stream()
                    .map(PollVote::getOptionId).toList();
            if (same(p, existing, chosen)) {
                return; // idempotent
            }
            if (!p.isAllowChangeVote()) {
                throw alreadyVoted();
            }
            revert(p, actor.id());
            ballot.setUpdatedAt(now);
            ballots.save(ballot);
        } else {
            ballots.save(new PollBallot(pollId, actor.id()));
            polls.addVoters(pollId, 1);
        }
        List<PollVote> rows = new ArrayList<>();
        for (int i = 0; i < chosen.size(); i++) {
            int rank = p.getType() == Poll.Type.RANKED ? i + 1 : 1;
            rows.add(new PollVote(pollId, chosen.get(i), actor.id(), rank));
        }
        votes.saveAll(rows);
        for (PollVote v : rows) {
            options.addCounts(v.getOptionId(), voteInc(p, v.getChoiceRank()), score(p, v.getChoiceRank()));
        }
    }

    @Transactional
    public PollView retract(Actor actor, Long pollId) {
        Poll p = polls.lockById(pollId).orElseThrow(PollService::notFound);
        checkOpen(p, actor, clock.instant());
        PollBallot ballot = ballots.findByPollIdAndUserId(pollId, actor.id()).orElse(null);
        if (ballot == null) {
            return assembler.view(p, actor, false); // idempotent
        }
        if (!p.isAllowChangeVote()) {
            throw alreadyVoted();
        }
        revert(p, actor.id());
        ballots.deleteByPollIdAndUserId(pollId, actor.id());
        polls.addVoters(pollId, -1);
        return assembler.view(polls.findById(pollId).orElseThrow(), actor, false);
    }

    /** Kullanicinin mevcut oylarini sayaclardan dusurur ve siler. */
    private void revert(Poll p, Long userId) {
        for (PollVote v : votes.findByPollIdAndUserIdOrderByChoiceRankAsc(p.getId(), userId)) {
            options.addCounts(v.getOptionId(), -voteInc(p, v.getChoiceRank()), -score(p, v.getChoiceRank()));
        }
        votes.deleteByPollIdAndUserId(p.getId(), userId);
        votes.flush(); // silme, ayni secenegi yeniden yazan eklemeden ONCE calissin (tekillik kisiti)
    }

    /** Taslak -> 404/NOT_OPEN, bitmis ya da suresi dolmus -> CLOSED, henuz acilmamis -> NOT_OPEN. */
    private void checkOpen(Poll p, Actor actor, Instant now) {
        if (p.getStatus() == Poll.Status.DRAFT) {
            if (!access.canManage(p, actor)) {
                throw PollService.notFound();
            }
            throw new ApiException(HttpStatus.CONFLICT, "POLL_NOT_OPEN", "Bu anket henüz açılmadı.");
        }
        if (p.isClosedAt(now)) {
            throw new ApiException(HttpStatus.CONFLICT, "POLL_CLOSED", "Bu anket kapalı.");
        }
        if (p.getOpensAt().isAfter(now)) {
            throw new ApiException(HttpStatus.CONFLICT, "POLL_NOT_OPEN", "Bu anket henüz açılmadı.");
        }
    }

    /** Istegi secenek kimliklerine cevirir ve kurallari denetler. */
    private List<Long> parse(Poll p, List<PollOption> opts, VoteRequest req) {
        if (req == null) {
            throw invalidVote();
        }
        Map<Long, PollOption> byId = new HashMap<>();
        opts.forEach(o -> byId.put(o.getId(), o));
        if (p.getType() == Poll.Type.RATING && req.rating() != null) {
            int r = req.rating();
            if (r < 1 || r > 5) {
                throw invalidVote();
            }
            return opts.stream().filter(o -> o.getPosition() == r).map(PollOption::getId).limit(1).toList();
        }
        List<Long> ids = req.optionIds();
        if (ids == null || ids.isEmpty() || ids.stream().anyMatch(java.util.Objects::isNull)
                || new HashSet<>(ids).size() != ids.size()) {
            throw invalidVote();
        }
        if (!byId.keySet().containsAll(ids)) {
            throw invalidVote();
        }
        int max = p.getType() == Poll.Type.SINGLE || p.getType() == Poll.Type.RATING ? 1 : p.getMaxChoices();
        if (ids.size() > max) {
            throw invalidVote();
        }
        return List.copyOf(ids);
    }

    private static boolean same(Poll p, List<Long> existing, List<Long> chosen) {
        return p.getType() == Poll.Type.RANKED ? existing.equals(chosen) : new HashSet<>(existing).equals(new HashSet<>(chosen))
                && existing.size() == chosen.size();
    }

    /** RANKED'de yalniz 1. tercih secenek sayacini artirir; digerlerinde her secim. */
    private static int voteInc(Poll p, int rank) {
        return p.getType() == Poll.Type.RANKED ? (rank == 1 ? 1 : 0) : 1;
    }

    /** Borda puani: n - sira + 1 (n = maxChoices). */
    private static int score(Poll p, int rank) {
        return p.getType() == Poll.Type.RANKED ? Math.max(0, p.getMaxChoices() - rank + 1) : 0;
    }

    private static ApiException invalidVote() {
        return new ApiException(HttpStatus.BAD_REQUEST, "POLL_INVALID_VOTE", "Geçersiz oy.");
    }

    private static ApiException alreadyVoted() {
        return new ApiException(HttpStatus.CONFLICT, "POLL_ALREADY_VOTED", "Bu ankette oyunuzu değiştiremezsiniz.");
    }
}
