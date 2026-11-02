package edu.bingol.backend.unitnews;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.unitnews.UnitNewsService.Target;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * "Bolumunuzde yeni duyuru" bildirimi (tasarim 03). Gece 01:00 cekimi bildirim gondermez (kullanicinin gece uykusunu
 * bolmesin); sabah {@code unitnews.notify.cron} (varsayilan 09:30) bekleyen yeni kayitlari tarar. Alici = profil
 * bolum/fakulte/sinifi {@link UnitNewsService#targetsFor} ile bu duyurunun kaynagina/bolum akisina denk gelen aktif
 * kullanicilar (eslesme yoksa kimseye gitmez). Kayit sahiplenilerek (notified_at) cift gonderim engellenir; kullanici
 * basina bir kosuda en cok {@value #MAX_PER_USER} bildirim gider (toplu cekimde yagmur olmasin). Yalniz veritabani
 * okunur; kaynak siteye istek ATILMAZ. Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class UnitNewsNotifier {

    private static final Logger log = LoggerFactory.getLogger(UnitNewsNotifier.class);
    static final int MAX_PER_USER = 3;
    static final int MAX_ANNOUNCEMENTS = 40;
    static final int USER_PAGE = 2000;
    /** Bundan eski (cekildigi an) bekleyenler gonderilmez; sessizce gonderilmis sayilir. */
    static final Duration MAX_AGE = Duration.ofDays(3);

    static final NotificationTemplates.Template TEMPLATE = NotificationTemplates.register("notif.unitnews.new",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.UNIT_ANNOUNCEMENT);

    private final UnitAnnouncementRepository anns;
    private final UnitSourceRepository sources;
    private final UnitNewsService unitNews;
    private final NotificationService notifications;
    private final JdbcTemplate jdbc;
    private SchedulerLock lock;

    @Value("${unitnews.notify.enabled:true}")
    private boolean enabled = true;

    @Autowired
    public UnitNewsNotifier(UnitAnnouncementRepository anns, UnitSourceRepository sources, UnitNewsService unitNews,
                            NotificationService notifications, JdbcTemplate jdbc) {
        this.anns = anns;
        this.sources = sources;
        this.unitNews = unitNews;
        this.notifications = notifications;
        this.jdbc = jdbc;
    }

    @Autowired(required = false)
    void setLock(ObjectProvider<SchedulerLock> lock) {
        this.lock = lock.getIfAvailable();
    }

    @Scheduled(cron = "${unitnews.notify.cron:0 30 9 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        if (!enabled) {
            return;
        }
        if (lock == null) {
            run();
        } else {
            lock.tryRunOrLocal("unitnews-notify", Duration.ofMinutes(30), this::run);
        }
    }

    /** @return bildirim kaydi yazilan toplam (duyuru, kullanici) cifti sayisi */
    public int run() {
        try {
            Instant now = Instant.now();
            Instant since = now.minus(MAX_AGE);
            // ilk dolumda cekilen eski (yayin tarihi 7 gunden eski) duyurular icin bildirim gonderilmez
            java.time.LocalDate published = java.time.LocalDate.now(java.time.ZoneId.of("Europe/Istanbul")).minusDays(7);
            anns.expirePending(since, published, now);
            List<UnitAnnouncement> pending = anns.pendingNotify(since, published, PageRequest.of(0, MAX_ANNOUNCEMENTS));
            if (pending.isEmpty()) {
                return 0;
            }
            // Kullanicilari (bolum, fakulte, sinif) uclusune gore grupla: hedef hesabi uclu basina bir kez
            Map<String, Group> groups = groupUsers();
            Map<Long, Integer> perUser = new HashMap<>();
            Map<String, String> sourceNames = new HashMap<>();
            int total = 0;
            for (UnitAnnouncement a : pending) {
                if (anns.claimNotify(a.getId(), now) != 1) {
                    continue; // baska ornek aldi
                }
                if (!sourceEnabled(a.getSourceCode(), sourceNames)) {
                    continue;
                }
                List<Long> recipients = new ArrayList<>();
                String label = null;
                for (Group g : groups.values()) {
                    Target hit = g.match(a);
                    if (hit == null) {
                        continue;
                    }
                    if (label == null && hit.unitName() != null) {
                        label = hit.unitName();
                    }
                    for (Long uid : g.userIds) {
                        if (perUser.merge(uid, 1, Integer::sum) <= MAX_PER_USER) {
                            recipients.add(uid);
                        }
                    }
                }
                if (recipients.isEmpty()) {
                    continue;
                }
                if (label == null) {
                    label = sourceNames.get(a.getSourceCode());
                }
                Map<String, String> data = new LinkedHashMap<>();
                data.put("target", "UNIT_NEWS");
                data.put("value", String.valueOf(a.getId()));
                data.put("unitNewsId", String.valueOf(a.getId()));
                if (label != null) {
                    data.put("label", label); // ust etiket: bolum (ya da kaynak) adi
                }
                total += notifications.sendTemplatedBulk(recipients, TEMPLATE, data, "unit:" + a.getId(), a.getTitle());
            }
            return total;
        } catch (RuntimeException e) {
            log.warn("Birim duyurusu bildirimi gonderilemedi: {}", e.toString());
            return 0;
        }
    }

    private boolean sourceEnabled(String code, Map<String, String> names) {
        if (names.containsKey(code)) {
            return true;
        }
        UnitSource s = sources.findById(code).filter(UnitSource::isEnabled).orElse(null);
        if (s == null) {
            return false;
        }
        names.put(code, s.getName());
        return true;
    }

    /** Ayni bolum/fakulte/sinif uclusunu paylasan aktif kullanicilar ve o uclunun hedefleri (bos hedefliler atilir). */
    private Map<String, Group> groupUsers() {
        Map<String, Group> groups = new LinkedHashMap<>();
        long after = 0;
        while (true) {
            List<Object[]> rows = jdbc.query("SELECT id, department, faculty, grade FROM app_user WHERE id > ? "
                    + "AND status = 'ACTIVE' AND department IS NOT NULL ORDER BY id LIMIT ?",
                    (rs, i) -> new Object[] {rs.getLong(1), rs.getString(2), rs.getString(3), rs.getString(4)},
                    after, USER_PAGE);
            for (Object[] r : rows) {
                String key = r[1] + "|" + r[2] + "|" + r[3];
                Group g = groups.get(key);
                if (g == null) {
                    List<Target> targets = unitNews.targetsFor((String) r[1], (String) r[2], (String) r[3]);
                    g = new Group(targets);
                    groups.put(key, g);
                }
                if (!g.targets.isEmpty()) {
                    g.userIds.add((Long) r[0]);
                }
            }
            if (rows.size() < USER_PAGE) {
                break;
            }
            after = (Long) rows.get(rows.size() - 1)[0];
        }
        groups.values().removeIf(g -> g.targets.isEmpty());
        return groups;
    }

    /** Hedefleri ortak kullanici grubu. */
    static final class Group {
        final List<Target> targets;
        final List<Long> userIds = new ArrayList<>();

        Group(List<Target> targets) {
            this.targets = targets;
        }

        /**
         * Duyuru bu gruba uyar mi: genel akis (dept_slug yok) kaynagin herhangi bir hedefine; bolum akisi yalniz o
         * bolumun hedefine. Uyan hedef doner (bolum adi etiket icin), uymazsa null.
         */
        Target match(UnitAnnouncement a) {
            Target general = null;
            for (Target t : targets) {
                if (!Objects.equals(t.sourceCode(), a.getSourceCode())) {
                    continue;
                }
                if (a.getDeptSlug() == null) {
                    general = general == null ? t : general;
                } else if (a.getDeptSlug().equals(t.deptSlug())) {
                    return t;
                }
            }
            return general;
        }
    }
}
