package edu.bingol.backend.forum.poll;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.forum.poll.spi.CreatePollRequest;
import edu.bingol.backend.forum.poll.spi.ForumPollService;
import edu.bingol.backend.forum.poll.spi.PollView;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Konu anketi: olusturma (konu olusturma islemine KATILIR: gecersiz anket konuyu da geri alir) ve gorunum.
 *
 * <p>Kurallar: 2-6 secenek, her biri en cok {@value #OPTION_MAX} karakter (bosluk/HTML temizlenir, buyuk-kucuk harf
 * duyarsiz tekrar yok), soru en cok {@value #QUESTION_MAX}, {@code endsAt} gelecekte ve en cok {@value #MAX_DAYS} gun
 * sonra, metinlere ContentGuard (uygunsuz ifade) uygulanir. Sonuclar herkese her zaman gorunur; oy verenlerin kimligi
 * hicbir yerde dondurulmez.
 */
@Service
public class ForumPollServiceImpl implements ForumPollService {

    static final int OPTIONS_MIN = 2;
    static final int OPTIONS_MAX = 6;
    static final int OPTION_MAX = 80;
    static final int QUESTION_MAX = 200;
    static final int MAX_DAYS = 30;

    private final ForumPollRepository polls;
    private final ForumPollOptionRepository options;
    private final ForumPollVoteRepository votes;
    private final ContentGuard guard;
    private final Clock clock;

    public ForumPollServiceImpl(ForumPollRepository polls, ForumPollOptionRepository options, ForumPollVoteRepository votes,
                                ContentGuard guard, Clock clock) {
        this.polls = polls;
        this.options = options;
        this.votes = votes;
        this.guard = guard;
        this.clock = clock;
    }

    /** Konu islemine katilir (REQUIRED): hata konuyu da geri alir. */
    @Override
    @Transactional
    public PollView createForTopic(Long topicId, CreatePollRequest req) {
        if (req == null) {
            throw invalid("FORUM_POLL_OPTIONS_INVALID", "Anket en az 2, en çok 6 seçenek içermelidir.");
        }
        Long actor = CurrentUser.idOrNull();
        String question = ForumPollText.clean(req.question());
        if (question != null && question.length() > QUESTION_MAX) {
            throw invalid("FORUM_POLL_QUESTION_TOO_LONG", "Anket sorusu en fazla 200 karakter olabilir.", String.valueOf(QUESTION_MAX));
        }
        List<String> texts = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (String raw : req.options() == null ? List.<String>of() : req.options()) {
            String t = ForumPollText.clean(raw);
            if (t == null) {
                throw invalid("FORUM_POLL_OPTIONS_INVALID", "Anket seçenekleri boş olamaz; en az 2, en çok 6 seçenek girin.");
            }
            if (t.length() > OPTION_MAX) {
                throw invalid("FORUM_POLL_OPTION_TOO_LONG", "Her seçenek en fazla 80 karakter olabilir.", String.valueOf(OPTION_MAX));
            }
            if (!seen.add(t.toLowerCase(Locale.ROOT))) {
                throw invalid("FORUM_POLL_DUPLICATE_OPTION", "Aynı seçenek birden fazla kez girilemez.");
            }
            texts.add(t);
        }
        if (texts.size() < OPTIONS_MIN || texts.size() > OPTIONS_MAX) {
            throw invalid("FORUM_POLL_OPTIONS_INVALID", "Anket en az 2, en çok 6 seçenek içermelidir.");
        }
        Instant now = clock.instant();
        Instant endsAt = req.endsAt();
        if (endsAt != null && (!endsAt.isAfter(now) || endsAt.isAfter(now.plus(Duration.ofDays(MAX_DAYS))))) {
            throw invalid("FORUM_POLL_ENDS_INVALID", "Bitiş zamanı gelecekte ve en fazla 30 gün sonrası olmalıdır.", String.valueOf(MAX_DAYS));
        }
        if (polls.findByTopicId(topicId).isPresent()) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_POLL_EXISTS", "Bu konunun zaten bir anketi var.");
        }
        // Uygunsuz ifade denetimi: ayrintili alan adlariyla (kelime yankilanmaz)
        if (question != null) {
            guard.assertClean(ContentGuard.Entity.OTHER, "poll.question", actor, question);
        }
        for (int i = 0; i < texts.size(); i++) {
            guard.assertClean(ContentGuard.Entity.OTHER, "poll.options[" + i + "]", actor, texts.get(i));
        }
        ForumPoll p = new ForumPoll();
        p.setTopicId(topicId);
        p.setQuestion(question);
        p.setEndsAt(endsAt);
        p.setAllowChangeVote(req.allowChangeVote());
        p.setCreatedAt(now);
        try {
            p = polls.saveAndFlush(p);
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_POLL_EXISTS", "Bu konunun zaten bir anketi var.");
        }
        List<ForumPollOption> saved = new ArrayList<>();
        for (int i = 0; i < texts.size(); i++) {
            saved.add(new ForumPollOption(p.getId(), texts.get(i), i));
        }
        options.saveAll(saved);
        return view(p, saved, actor, null, now);
    }

    /** Konunun anketi; yoksa null. Gorunurluk denetimi cagiranda (konu gorunurlugu A'da). */
    @Override
    @Transactional(readOnly = true)
    public PollView pollFor(Long topicId, Long viewerId) {
        return polls.findByTopicId(topicId).map(p -> view(p, viewerId)).orElse(null);
    }

    /** Verilen konulardan anketi olanlar (liste kartlarindaki hasPoll icin tek sorgu). */
    @Override
    @Transactional(readOnly = true)
    public Set<Long> topicIdsWithPoll(Collection<Long> topicIds) {
        if (topicIds == null || topicIds.isEmpty()) {
            return Set.of();
        }
        Set<Long> out = new HashSet<>();
        for (ForumPoll p : polls.findByTopicIdIn(topicIds)) {
            out.add(p.getTopicId());
        }
        return out;
    }

    /** Konu listeleri icin toplu (N+1 yok): konu kimligi -> anket gorunumu. */
    @Transactional(readOnly = true)
    public Map<Long, PollView> pollsFor(Collection<Long> topicIds, Long viewerId) {
        if (topicIds.isEmpty()) {
            return Map.of();
        }
        List<ForumPoll> ps = polls.findByTopicIdIn(topicIds);
        if (ps.isEmpty()) {
            return Map.of();
        }
        List<Long> pollIds = ps.stream().map(ForumPoll::getId).toList();
        Map<Long, List<ForumPollOption>> byPoll = new HashMap<>();
        for (ForumPollOption o : options.findByPollIdInOrderByPollIdAscPositionAscIdAsc(pollIds)) {
            byPoll.computeIfAbsent(o.getPollId(), k -> new ArrayList<>()).add(o);
        }
        Map<Long, Long> mine = new HashMap<>();
        if (viewerId != null) {
            for (Object[] row : votes.choicesOf(viewerId, pollIds)) {
                mine.put((Long) row[0], (Long) row[1]);
            }
        }
        Instant now = clock.instant();
        Map<Long, PollView> out = new HashMap<>();
        for (ForumPoll p : ps) {
            out.put(p.getTopicId(), view(p, byPoll.getOrDefault(p.getId(), List.of()), viewerId, mine.get(p.getId()), now));
        }
        return out;
    }

    /** Tek anket gorunumu (oy ucundan da kullanilir). */
    public PollView view(ForumPoll p, Long viewerId) {
        Long mine = viewerId == null ? null : votes.optionOf(p.getId(), viewerId).orElse(null);
        return view(p, options.findByPollIdOrderByPositionAscIdAsc(p.getId()), viewerId, mine, clock.instant());
    }

    /** Saf gorunum: yuzde 1 ondalik, toplam 0 ise %0; oy veren kimligi YOK. */
    public PollView view(ForumPoll p, List<ForumPollOption> opts, Long viewerId, Long myOptionId, Instant now) {
        int total = 0;
        for (ForumPollOption o : opts) {
            total += o.getVoteCount();
        }
        List<PollView.Option> items = new ArrayList<>(opts.size());
        for (ForumPollOption o : opts) {
            items.add(new PollView.Option(o.getId(), o.getText(), o.getVoteCount(), percent(o.getVoteCount(), total)));
        }
        boolean closed = p.isClosedAt(now);
        boolean canVote = viewerId != null && !closed && (myOptionId == null || p.isAllowChangeVote());
        return new PollView(p.getId(), p.getQuestion(), items, total, myOptionId, p.getEndsAt(), closed,
                p.isAllowChangeVote(), canVote);
    }

    /** Yuzde: 0-100, 1 ondalik (yari yukari); toplam 0 ise 0. */
    static double percent(long count, long total) {
        if (total <= 0 || count <= 0) {
            return 0.0;
        }
        return Math.round(count * 1000.0 / total) / 10.0;
    }

    private static ApiException invalid(String code, String message, Object... args) {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, code, message, args);
    }
}
