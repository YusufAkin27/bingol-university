package edu.bingol.backend.menu;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.menu.dto.MenuDish;
import edu.bingol.backend.menu.dto.MenuResponse;
import edu.bingol.backend.notification.NotificationPrefRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationType;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gunluk "Bugunun menusu" bildirimi (tasarim 05). YALNIZ veritabanindaki menuyu kullanir (kaynak siteye istek ATILMAZ,
 * bkz. CLAUDE.md scraping kurali); kalori ve gorsel {@link MenuService#today()} ile ayni kaynaktandir. Yalniz
 * "Bugunun menusu" tercihini ACAN kullanicilara gider (varsayilan kapali, NotificationPref#menuDaily). Menu yoksa
 * hicbir sey gonderilmez. Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class MenuDailyNotifier {

    private static final Logger log = LoggerFactory.getLogger(MenuDailyNotifier.class);
    static final int PAGE = 1000;
    /** En cok bu kadar yemek govdede sayilir (kalani "..." ile kisalir). */
    static final int MAX_DISHES = 5;

    static final NotificationTemplates.Template COMPLETE = NotificationTemplates.register("notif.menu.today",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.MENU_DAILY);
    static final NotificationTemplates.Template PARTIAL = NotificationTemplates.register("notif.menu.todayPartial",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.MENU_DAILY);
    static final NotificationTemplates.Template PLAIN = NotificationTemplates.register("notif.menu.todayPlain",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.MENU_DAILY);

    private final MenuService menu;
    private final NotificationPrefRepository prefs;
    private final NotificationService notifications;
    private SchedulerLock lock;

    @Value("${menu.daily-push.enabled:true}")
    private boolean enabled = true;

    @Autowired
    public MenuDailyNotifier(MenuService menu, NotificationPrefRepository prefs, NotificationService notifications) {
        this.menu = menu;
        this.prefs = prefs;
        this.notifications = notifications;
    }

    @Autowired(required = false)
    void setLock(ObjectProvider<SchedulerLock> lock) {
        this.lock = lock.getIfAvailable();
    }

    /** Hafta ici 11:00 (Istanbul): ogle yemegi oncesi. Ayar: menu.daily-push.cron */
    @Scheduled(cron = "${menu.daily-push.cron:0 0 11 * * MON-FRI}", zone = "Europe/Istanbul")
    public void scheduled() {
        if (!enabled) {
            return;
        }
        Runnable job = () -> run();
        if (lock == null) {
            job.run();
        } else {
            lock.tryRunOrLocal("menu-daily-push", Duration.ofMinutes(30), job);
        }
    }

    /** @return bildirim kaydi yazilan kullanici sayisi (menu ya da alici yoksa 0) */
    public int run() {
        try {
            Optional<MenuResponse> today = menu.today();
            if (today.isEmpty() || today.get().items() == null || today.get().items().isEmpty()) {
                return 0;
            }
            MenuResponse m = today.get();
            NotificationTemplates.Template t = m.totalKcal() == null ? PLAIN : m.kcalComplete() ? COMPLETE : PARTIAL;
            Map<String, String> data = new LinkedHashMap<>();
            data.put("target", "MENU");
            data.put("value", m.date());
            data.put("menuDate", m.date());
            if (m.imageUrl() != null && !m.imageUrl().isBlank()) {
                data.put("imageUrl", m.imageUrl()); // herkese acik menu gorseli (kutuda da gosterilir)
            }
            String dishes = dishLine(m);
            String kcal = m.totalKcal() == null ? "" : String.valueOf(m.totalKcal());
            int total = 0;
            long after = 0;
            while (true) {
                List<Long> ids = prefs.menuDailyUserIds(after, PageRequest.of(0, PAGE));
                if (ids.isEmpty()) {
                    break;
                }
                total += notifications.sendTemplatedBulk(ids, t, data, "menu:" + m.date(), dishes, kcal);
                after = ids.get(ids.size() - 1);
                if (ids.size() < PAGE) {
                    break;
                }
            }
            return total;
        } catch (RuntimeException e) {
            log.warn("Gunluk menu bildirimi gonderilemedi: {}", e.toString());
            return 0;
        }
    }

    /** "Mercimek Corbasi, Orman Kebabi, Pilav" (en cok {@link #MAX_DISHES}); yemek adlari icerik oldugundan cevrilmez. */
    public static String dishLine(MenuResponse m) {
        List<String> names = m.dishes() == null || m.dishes().isEmpty() ? m.items()
                : m.dishes().stream().map(MenuDish::name).collect(Collectors.toList());
        String joined = names.stream().limit(MAX_DISHES).collect(Collectors.joining(", "));
        return names.size() > MAX_DISHES ? joined + "…" : joined;
    }
}
