package edu.bingol.backend.poll;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
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
            for (Poll p : polls.findByStatusAndClosesAtLessThanEqual(Poll.Status.OPEN, now)) {
                if (service.autoClose(p.getId())) {
                    closed++;
                }
            }
            polls.openedNotNotified(now).forEach(p -> notifier.notifyOpened(p.getId()));
            polls.closingSoonNotNotified(now, now.plus(Duration.ofHours(24))).forEach(notifier::notifyClosingSoon);
            if (closed > 0) {
                log.info("{} anket suresi doldugu icin kapatildi", closed);
            }
        } catch (RuntimeException e) {
            log.warn("Anket bakim isi basarisiz: {}", e.toString());
        }
        return closed;
    }
}
