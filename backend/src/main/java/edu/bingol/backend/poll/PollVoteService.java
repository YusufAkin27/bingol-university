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
import java.util.TreeMap;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Oy verme/geri cekme. Yaris guvenligi: anket satiri KILITLENMEZ; ayni kullanicinin istekleri kendi ballot satirinda
 * (yeni secmen: (poll_id,user_id) tekillik kisiti) siraya girer, sayaclar en sonda sirali atomik UPDATE ile
 * artar/azalir. Idempotent: ayni oy tekrar gonderilirse degisiklik olmaz.
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
     * Oy ver. Anket satiri KILITLENMEZ (yuk testi: tek ankete 300-600 es zamanli oy, FOR UPDATE ile siraya girip
     * lock_timeout'u asiyor ve Hikari havuzunu dolduruyordu). Bunun yerine:
     * <ul>
     *   <li>kural denetimi ve secenek cozumleme islem DISINDA (kilitsiz) yapilir;</li>
     *   <li>ayni kullanicinin es zamanli istekleri kendi ballot satirinda (yeni secmense (poll_id,user_id) tekillik
     *       kisitinda) siraya girer: cift oy yok, farkli kullanicilar birbirini beklemez;</li>
     *   <li>ballot + oy satirlari once, sayaclar EN SON ve secenek kimligine gore sirali tek hamlede atomik
     *       {@code UPDATE ... SET n = n + k} ile yazilir: sicak satir kilidi yalniz bu birkac ifade ile commit arasinda
     *       tutulur ve kilit sirasi hep ayni oldugu icin kilitlenme olmaz. Anketin hala acik oldugu ayni ifadede
     *       dogrulanir ({@link PollRepository#addVotersIfOpen}).</li>
     * </ul>
     * Gizli oy: oy satiri kimlik tasir (tek-oy kurali icin) ancak hicbir uc kimligi gostermez (degismedi).
     */
    public PollView vote(Actor actor, Long pollId, VoteRequest req) {
        for (int attempt = 0; ; attempt++) {
            Poll pre = polls.findById(pollId).orElseThrow(PollService::notFound);
            List<PollOption> opts = options.findByPollIdOrderByPositionAsc(pollId);
            List<Long> chosen = prepare(pre, opts, actor, req, clock.instant());
            try {
                tx.executeWithoutResult(s -> write(pre, actor, chosen, clock.instant()));
                return assembler.view(polls.findById(pollId).orElseThrow(), actor, false);
            } catch (DataIntegrityViolationException e) {
                // (a) ayni kullanicinin es zamanli ilk iki istegi: ikincisi tekillik kisitina carpti -> yeniden dene, bu kez
                //     ballot gorunur (idempotent/degisiklik yolu). (b) secenekler arada degisti (FK) -> hazirligi yenile.
                if (attempt >= 2) {
                    throw invalidVote();
                }
            } catch (PessimisticLockingFailureException e) {
                // Sicak sayac satirinda lock_timeout (burst): islem geri alindi, hicbir sey yazilmadi -> kisa beklemeyle
                // yeniden dene (tekillik/idempotans sayesinde cift oy olmaz). Hala olmazsa 503 DB_TIMEOUT'a duser.
                if (attempt >= 2) {
                    throw e;
                }
                backoff(attempt);
            }
        }
    }

    /** Yeniden denemeden once rastgele kisa bekleme (herkes ayni anda tekrar yuklenmesin). */
    private static void backoff(int attempt) {
        try {
            Thread.sleep(50L * (attempt + 1) + java.util.concurrent.ThreadLocalRandom.current().nextInt(100));
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
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

    /** Islem icinde: kullanici kilidi, ballot/oy satirlari, en sonda sirali atomik sayaclar (idempotent). */
    private void write(Poll p, Actor actor, List<Long> chosen, Instant now) {
        Long pollId = p.getId();
        // Sayac farklari secenek kimligine gore SIRALI uygulanir (sabit kilit sirasi = kilitlenme yok); ayni secenegin
        // eksi/arti farki birlesir (degisiklikte gereksiz yazma yok).
        Map<Long, int[]> delta = new TreeMap<>();
        int voterDelta = 0;
        PollBallot ballot = ballots.lockByPollIdAndUserId(pollId, actor.id()).orElse(null);
        if (ballot != null) {
            List<PollVote> old = votes.findByPollIdAndUserIdOrderByChoiceRankAsc(pollId, actor.id());
            List<Long> existing = old.stream().map(PollVote::getOptionId).toList();
            if (same(p, existing, chosen)) {
                return; // idempotent
            }
            if (!p.isAllowChangeVote()) {
                throw alreadyVoted();
            }
            for (PollVote v : old) {
                bump(delta, v.getOptionId(), -voteInc(p, v.getChoiceRank()), -score(p, v.getChoiceRank()));
            }
            votes.deleteByPollIdAndUserId(pollId, actor.id());
            votes.flush(); // silme, ayni secenegi yeniden yazan eklemeden ONCE calissin (tekillik kisiti)
            ballot.setUpdatedAt(now);
            ballots.save(ballot);
        } else {
            ballots.saveAndFlush(new PollBallot(pollId, actor.id())); // es zamanli ikinci istek burada tekillige carpar
            voterDelta = 1;
        }
        List<PollVote> rows = new ArrayList<>();
        for (int i = 0; i < chosen.size(); i++) {
            int rank = p.getType() == Poll.Type.RANKED ? i + 1 : 1;
            rows.add(new PollVote(pollId, chosen.get(i), actor.id(), rank));
        }
        votes.saveAll(rows);
        for (PollVote v : rows) {
            bump(delta, v.getOptionId(), voteInc(p, v.getChoiceRank()), score(p, v.getChoiceRank()));
        }
        applyCounters(p, voterDelta, delta, now);
    }

    /**
     * Sayaclari en sonda yazar (T-069): once secenekler (kimlik sirasiyla), anket satiri ISLEMIN SON ifadesi.
     * Tum oylar ayni {@code poll} satirinda ({@code voter_count}) cakisir; satir kilidi UPDATE'ten commit'e kadar
     * tutuldugu icin onceden anket UPDATE'i basta olunca kilit 3 secenek guncellemesi + commit suresince tutuluyor,
     * tek ankete ~30 oy/sn tavani vardi (A2-06). Artik kilit yalniz son ifade + commit suresince tutulur.
     * Kilit sirasi hep ayni (secenekler artan kimlik, sonra anket) oldugu icin kilitlenme olmaz.
     *
     * <p>Secmen sayisi degismiyorsa (oy degisikligi, {@code voterDelta == 0}) sicak anket satirina HIC dokunulmaz;
     * anketin hala acik oldugu kilitsiz sayimla dogrulanir (hazirlik asamasinda zaten denetlendi; kalan pencere
     * yalniz yonetici durum degisikligidir).
     */
    private void applyCounters(Poll p, int voterDelta, Map<Long, int[]> delta, Instant now) {
        delta.forEach((optionId, d) -> {
            if (d[0] != 0 || d[1] != 0) {
                options.addCounts(optionId, d[0], d[1]);
            }
        });
        boolean open = voterDelta != 0 ? polls.addVotersIfOpen(p.getId(), voterDelta, now) > 0
                : polls.countOpenAt(p.getId(), now) > 0;
        if (!open) {
            // Okuma ile yazma arasinda kapandi/iptal edildi: islem geri alinir (secenek sayaclari da)
            Poll fresh = polls.findById(p.getId()).orElseThrow(PollService::notFound);
            if (fresh.getStatus() == Poll.Status.OPEN && fresh.getOpensAt().isAfter(now)) {
                throw new ApiException(HttpStatus.CONFLICT, "POLL_NOT_OPEN", "Bu anket henüz açılmadı.");
            }
            throw new ApiException(HttpStatus.CONFLICT, "POLL_CLOSED", "Bu anket kapalı.");
        }
    }

    private static void bump(Map<Long, int[]> delta, Long optionId, int votes, int score) {
        int[] d = delta.computeIfAbsent(optionId, k -> new int[2]);
        d[0] += votes;
        d[1] += score;
    }

    /** Geri cekme: oy ile ayni kilit sirasi (kullanici ballot'u -> anket sayaci -> secenekler); anket satiri kilitlenmez. */
    public PollView retract(Actor actor, Long pollId) {
        Poll pre = polls.findById(pollId).orElseThrow(PollService::notFound);
        checkOpen(pre, actor, clock.instant());
        tx.executeWithoutResult(s -> {
            PollBallot ballot = ballots.lockByPollIdAndUserId(pollId, actor.id()).orElse(null);
            if (ballot == null) {
                return; // idempotent
            }
            if (!pre.isAllowChangeVote()) {
                throw alreadyVoted();
            }
            Map<Long, int[]> delta = new TreeMap<>();
            for (PollVote v : votes.findByPollIdAndUserIdOrderByChoiceRankAsc(pollId, actor.id())) {
                bump(delta, v.getOptionId(), -voteInc(pre, v.getChoiceRank()), -score(pre, v.getChoiceRank()));
            }
            votes.deleteByPollIdAndUserId(pollId, actor.id());
            ballots.deleteByPollIdAndUserId(pollId, actor.id());
            ballots.flush();
            applyCounters(pre, -1, delta, clock.instant());
        });
        return assembler.view(polls.findById(pollId).orElseThrow(), actor, false);
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
