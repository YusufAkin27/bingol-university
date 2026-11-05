package edu.bingol.backend.forum.poll;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.poll.spi.PollView;
import edu.bingol.backend.forum.topic.spi.ForumTopicLookup;
import edu.bingol.backend.forum.topic.spi.TopicRef;
import java.time.Clock;
import java.util.Optional;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Oy verme / degistirme / geri alma. Yaris guvenligi:
 * <ul>
 *   <li>Cift oy imkansiz: PK(poll_id, user_id). Es zamanli iki ilk oy: ikincisi tekillik kisitina carpar, islem geri
 *       alinir ve YENIDEN denenir (bu kez oy gorunur: ayni secenekse idempotent, farkliysa degisim kurali).</li>
 *   <li>Oy degisimi kosulludur ({@code UPDATE ... WHERE option_id = eski}): es zamanli iki degisimde yalniz biri
 *       etkilenir, digeri yeniden okur; sayaclar kimsenin oyunu iki kez saymaz/kaybetmez.</li>
 *   <li>Sayaclar okuma-degistir-yaz DEGIL, atomik {@code vote_count = vote_count + k} UPDATE'idir; ayni islemde
 *       secenek kimligine gore SIRALI uygulanir (kilitlenme olmaz).</li>
 *   <li>Aynı secenege tekrar oy idempotenttir (degisiklik yok, hata yok).</li>
 * </ul>
 * Oy verenler kimlikle hicbir yerde dondurulmez.
 */
@Service
public class ForumPollVoteService {

    private static final int MAX_ATTEMPTS = 4;

    private final ForumPollRepository polls;
    private final ForumPollOptionRepository options;
    private final ForumPollVoteRepository votes;
    /** A alani uygular; bean yoksa (A henuz birlesmedi) uygulama yine acilir, konu gorunmez sayilir (404). */
    private final ObjectProvider<ForumTopicLookup> topics;
    private final ForumPollServiceImpl service;
    private final Clock clock;
    private final TransactionTemplate tx;

    public ForumPollVoteService(ForumPollRepository polls, ForumPollOptionRepository options, ForumPollVoteRepository votes,
                                ObjectProvider<ForumTopicLookup> topics, ForumPollServiceImpl service, Clock clock,
                                PlatformTransactionManager txManager) {
        this.polls = polls;
        this.options = options;
        this.votes = votes;
        this.topics = topics;
        this.service = service;
        this.clock = clock;
        this.tx = new TransactionTemplate(txManager);
    }

    /** Konunun anketini gorunumle; konu gorunmez/anket yoksa 404. */
    public PollView get(Long topicId, Long viewerId) {
        ForumPoll p = open(topicId, viewerId, false);
        return service.view(p, viewerId);
    }

    /** Oy ver ya da oyu degistir. */
    public PollView vote(Long topicId, Long userId, Long optionId) {
        ForumPoll p = open(topicId, userId, true);
        if (p.isClosedAt(clock.instant())) {
            throw closed();
        }
        ForumPollOption opt = optionId == null ? null : options.findById(optionId).orElse(null);
        if (opt == null || !opt.getPollId().equals(p.getId())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "FORUM_POLL_OPTION_NOT_FOUND", "Seçenek bulunamadı.");
        }
        run(() -> applyVote(p, userId, optionId));
        return service.view(polls.findById(p.getId()).orElseThrow(), userId);
    }

    /** Oyu geri al (yalniz oy degistirmeye izin veren ve acik anket). Oy yoksa idempotent. */
    public PollView retract(Long topicId, Long userId) {
        ForumPoll p = open(topicId, userId, true);
        if (p.isClosedAt(clock.instant())) {
            throw closed();
        }
        if (!p.isAllowChangeVote()) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_POLL_CHANGE_NOT_ALLOWED", "Bu ankette oy geri alınamaz.");
        }
        run(() -> applyRetract(p, userId));
        return service.view(polls.findById(p.getId()).orElseThrow(), userId);
    }

    // --- cekirdek ---

    /** Konu gorunur mu, anket var mi; {@code forWrite} ise konu aktif ve kilitsiz olmali. */
    private ForumPoll open(Long topicId, Long viewerId, boolean forWrite) {
        ForumTopicLookup lookup = topics.getIfAvailable();
        Optional<TopicRef> ref = lookup == null ? Optional.empty() : lookup.visibleTopic(topicId, viewerId);
        if (ref.isEmpty() || (forWrite && ref.get().status() != TopicRef.Status.ACTIVE)) {
            throw notFound();
        }
        ForumPoll p = polls.findByTopicId(topicId).orElseThrow(ForumPollVoteService::notFound);
        if (forWrite && ref.get().locked()) {
            throw closed(); // kilitli konuda oy yok
        }
        return p;
    }

    /** Islem + kisa yeniden deneme dongusu (istisna islemin DISINDA yakalanir: PostgreSQL'de hata islemi bozar). */
    private void run(Runnable body) {
        for (int attempt = 0; ; attempt++) {
            try {
                tx.executeWithoutResult(s -> body.run());
                return;
            } catch (DataIntegrityViolationException | Retry | PessimisticLockingFailureException e) {
                if (attempt >= MAX_ATTEMPTS - 1) {
                    throw new ApiException(HttpStatus.CONFLICT, "FORUM_POLL_BUSY",
                            "Oyunuz şu an işlenemedi, lütfen tekrar deneyin.");
                }
                backoff(attempt);
            }
        }
    }

    private void applyVote(ForumPoll p, Long userId, Long optionId) {
        Optional<Long> current = votes.optionOf(p.getId(), userId);
        if (current.isPresent()) {
            Long old = current.get();
            if (old.equals(optionId)) {
                return; // ayni secenege tekrar oy: idempotent
            }
            if (!p.isAllowChangeVote()) {
                throw new ApiException(HttpStatus.CONFLICT, "FORUM_POLL_ALREADY_VOTED", "Bu ankette oyunuzu değiştiremezsiniz.");
            }
            if (votes.changeOption(p.getId(), userId, old, optionId) == 0) {
                throw new Retry(); // arada baska istek degistirdi/geri aldi: yeniden oku
            }
            adjust(old, -1, optionId, +1);
        } else {
            votes.insertVote(p.getId(), userId, optionId); // cift oy: tekillik kisiti -> yeniden dene
            adjust(null, 0, optionId, +1);
        }
    }

    private void applyRetract(ForumPoll p, Long userId) {
        Optional<Long> current = votes.optionOf(p.getId(), userId);
        if (current.isEmpty()) {
            return;
        }
        if (votes.deleteVote(p.getId(), userId, current.get()) == 0) {
            throw new Retry();
        }
        adjust(current.get(), -1, null, 0);
    }

    /** Sayaclari secenek kimligine gore sirali, atomik uygular. */
    private void adjust(Long a, int da, Long b, int db) {
        if (a != null && b != null && a > b) {
            Long t = a;
            a = b;
            b = t;
            int td = da;
            da = db;
            db = td;
        }
        if (a != null && da != 0) {
            options.addVotes(a, da);
        }
        if (b != null && db != 0) {
            options.addVotes(b, db);
        }
    }

    private static void backoff(int attempt) {
        try {
            Thread.sleep(20L * (attempt + 1) + java.util.concurrent.ThreadLocalRandom.current().nextInt(40));
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_POLL_NOT_FOUND", "Anket bulunamadı.");
    }

    private static ApiException closed() {
        return new ApiException(HttpStatus.CONFLICT, "FORUM_POLL_CLOSED", "Bu anket kapalı, oy kullanılamaz.");
    }

    /** Es zamanli degisim algilandi: islemi geri al, yeniden dene. */
    private static final class Retry extends RuntimeException {
        Retry() {
            super(null, null, false, false);
        }
    }
}
