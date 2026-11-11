package edu.bingol.backend.poll;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Anket bakim isi (Europe/Istanbul; coklu ornekte SchedulerLock): suresi dolan anketleri kapatir, "anket acildi" ve
 * "24 saat kaldi" bildirimlerini gonderir. Oy aninda sure zaten denetlendigi icin gecikme oy tutarliligini bozmaz.
 * Menu anketini her gece onceden olusturur. Hata cagirana sizmaz.
 */
@Component
public class PollCloseJob {

    private static final Logger log = LoggerFactory.getLogger(PollCloseJob.class);

    static final int BATCH = 100;
    static final int MAX_BATCHES = 20;

    private final PollRepository polls;
    private final PollService service;
    private final PollNotifier notifier;
    private final PollMenuService menu;
    private final SchedulerLock lock;
    private final Clock clock;

    public PollCloseJob(PollRepository polls, PollService service, PollNotifier notifier, PollMenuService menu,
                        SchedulerLock lock, Clock clock) {
        this.polls = polls;
        this.service = service;
        this.notifier = notifier;
        this.menu = menu;
        this.lock = lock;
        this.clock = clock;
    }

    @Scheduled(cron = "${app.poll.close-cron:0 */10 * * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        lock.tryRun("poll-close", Duration.ofMinutes(10), this::runOnce);
    }

    @Scheduled(cron = "0 5 0 * * *", zone = "Europe/Istanbul")
    public void ensureMenuPoll() {
        lock.tryRun("poll-menu", Duration.ofMinutes(2), menu::ensureToday);
    }

    /** @return kapatilan anket sayisi */
    public int runOnce() {
        int closed = 0;
        try {
            Instant now = clock.instant();
            Instant soon = now.plus(Duration.ofHours(24));
            // Sinirsiz liste yok: id'ye gore ilerleyen BATCH'lik parcalar, tur basina en cok MAX_BATCHES parca
            Long after = 0L;
            for (int i = 0; i < MAX_BATCHES; i++) {
                List<Poll> page = polls.findByStatusAndClosesAtLessThanEqualAndIdGreaterThanOrderByIdAsc(
                        Poll.Status.OPEN, now, after, PageRequest.of(0, BATCH));
                for (Poll p : page) {
                    if (service.autoClose(p.getId())) {
                        closed++;
                    }
                }
                if (page.size() < BATCH) break;
                after = page.get(page.size() - 1).getId();
            }
            after = 0L;
            for (int i = 0; i < MAX_BATCHES; i++) {
                List<Poll> page = polls.openedNotNotifiedPage(now, Poll.Status.OPEN, after, PageRequest.of(0, BATCH));
                page.forEach(p -> notifier.notifyOpened(p.getId()));
                if (page.size() < BATCH) break;
                after = page.get(page.size() - 1).getId();
            }
            after = 0L;
            for (int i = 0; i < MAX_BATCHES; i++) {
                List<Poll> page = polls.closingSoonPage(now, soon, Poll.Status.OPEN, after, PageRequest.of(0, BATCH));
                page.forEach(notifier::notifyClosingSoon);
                if (page.size() < BATCH) break;
                after = page.get(page.size() - 1).getId();
            }
            if (closed > 0) {
                log.info("{} anket suresi doldugu icin kapatildi", closed);
            }
        } catch (RuntimeException e) {
            log.warn("Anket bakim isi basarisiz: {}", e.toString());
        }
        return closed;
    }
}
