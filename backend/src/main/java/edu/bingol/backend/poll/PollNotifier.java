package edu.bingol.backend.poll;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import jakarta.annotation.PreDestroy;
import java.time.Clock;
import java.time.Instant;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Anket bildirimleri: yalniz `notify=true`. Anket acildiginda ve kapanisa 24 saat kala (henuz oy vermemis uygun kullanicilara).
 * GLOBAL -> ANNOUNCEMENT, COMMUNITY -> COMMUNITY turu (kullanici tercihi kapaliysa gitmez). Cift gonderimi onlemek icin
 * once isaret yazilir, sonra gonderilir. Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class PollNotifier {

    private static final Logger log = LoggerFactory.getLogger(PollNotifier.class);

    private final PollRepository polls;
    private final PollAccess access;
    private final NotificationService notifications;
    private final I18n i18n;
    private final Clock clock;
    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "poll-notify");
        t.setDaemon(true);
        return t;
    });

    public PollNotifier(PollRepository polls, PollAccess access, NotificationService notifications, I18n i18n, Clock clock) {
        this.polls = polls;
        this.access = access;
        this.notifications = notifications;
        this.i18n = i18n;
        this.clock = clock;
    }

    @TransactionalEventListener(fallbackExecution = true)
    void onPublished(PollPublished e) {
        try {
            executor.execute(() -> notifyOpened(e.pollId()));
        } catch (RuntimeException ex) {
            log.debug("Anket bildirimi siraya alinamadi, zamanlayici alacak: {}", ex.toString());
        }
    }

    /** @return bildirim gonderildi mi */
    public boolean notifyOpened(Long pollId) {
        try {
            Poll p = polls.findById(pollId).orElse(null);
            Instant now = clock.instant();
            if (p == null || !p.isNotify() || p.getStatus() != Poll.Status.OPEN || p.getOpenedNotifiedAt() != null
                    || p.getOpensAt().isAfter(now) || p.isExpired(now)) {
                return false;
            }
            // 24 saatten kisa anketlerde "kapaniyor" hatirlatmasi ayrica gonderilmez
            boolean shortLived = p.getClosesAt() != null && p.getClosesAt().isBefore(p.getOpensAt().plusSeconds(24 * 3600));
            // Hedefli UPDATE: oy sayaclarini ezen tam-entity kaydi yapilmaz; sartli oldugu icin cift gonderim olmaz
            if (polls.markOpenedNotified(p.getId(), now) == 0) {
                return false;
            }
            if (shortLived) {
                polls.markClosingNotified(p.getId(), now);
            }
            if (p.getScope() == Poll.Scope.GLOBAL && !p.hasAudience()) {
                notifications.broadcastLocalized(NotificationType.ANNOUNCEMENT, "polls",
                        lang -> i18n.msg("notif.poll.opened.title", lang),
                        lang -> i18n.msg("notif.poll.opened.body", lang, p.getTitle()), data(p));
            } else {
                send(p, recipients(p, false), "notif.poll.opened");
            }
            return true;
        } catch (RuntimeException e) {
            log.warn("Anket acildi bildirimi gonderilemedi (anket {}): {}", pollId, e.toString());
            return false;
        }
    }

    /** Kapanisa 24 saat kala: oy vermemis uygun kullanicilara. */
    public boolean notifyClosingSoon(Poll p) {
        try {
            if (!p.isNotify() || p.getClosingNotifiedAt() != null || p.getStatus() != Poll.Status.OPEN) {
                return false;
            }
            if (polls.markClosingNotified(p.getId(), clock.instant()) == 0) {
                return false;
            }
            send(p, recipients(p, true), "notif.poll.closing");
            return true;
        } catch (RuntimeException e) {
            log.warn("Anket kapaniyor bildirimi gonderilemedi (anket {}): {}", p.getId(), e.toString());
            return false;
        }
    }

    private List<Long> recipients(Poll p, boolean onlyNonVoters) {
        Set<Long> ids = new HashSet<>(p.getScope() == Poll.Scope.COMMUNITY ? access.communityUserIds(p.getCommunityId())
                : access.audienceUserIds(p));
        if (p.getScope() == Poll.Scope.COMMUNITY && p.hasAudience()) {
            ids.retainAll(access.audienceUserIds(p));
        }
        if (onlyNonVoters) {
            ids.removeAll(access.voterIds(p.getId()));
        }
        return List.copyOf(ids);
    }

    private void send(Poll p, List<Long> userIds, String key) {
        NotificationType type = p.getScope() == Poll.Scope.COMMUNITY ? NotificationType.COMMUNITY : NotificationType.ANNOUNCEMENT;
        Map<String, String> data = data(p);
        for (Long uid : userIds) {
            notifications.sendTemplated(uid, type, NotificationSubtype.POLL, key, data, p.getTitle());
        }
    }

    private static Map<String, String> data(Poll p) {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("pollId", String.valueOf(p.getId()));
        if (p.getCommunityId() != null) {
            d.put("communityId", String.valueOf(p.getCommunityId()));
        }
        return d;
    }

    @PreDestroy
    void shutdown() {
        executor.shutdown();
    }
}
