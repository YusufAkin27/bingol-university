package edu.bingol.backend.menu;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.menu.dto.MenuResponse;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.PushDisplay;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gunluk menu bildirimi: tercihi KAPATMAMIS (`notification_pref.meal_menu` FALSE olmayan; satiri olmayanlar dahil, varsayilan acik) aktif kullanicilara, gunde en
 * cok bir kez ve yalniz o gun icin menu varsa. Kalori toplami YALNIZ tum yemeklerin kalorisi girilmisse ({@code
 * kcalComplete}), gorsel yalniz menu icerigine bagli gorsel varsa ("yeni gorsel bekliyor" ise yok) eklenir. Kaynak
 * siteye istek atmaz (senkron zaten veritabanina yazmistir). Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class MealMenuNotifier {

    private static final Logger log = LoggerFactory.getLogger(MealMenuNotifier.class);
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final NotificationTemplates.Template TEMPLATE = NotificationTemplates.register("notif.meal.today",
            NotificationType.ANNOUNCEMENT, NotificationSubtype.MEAL_MENU);
    private static final int PAGE = 1000;
    private static final int MAX_PAGES = 200;

    private final MenuService menus;
    private final NotificationService notifications;
    private final JdbcTemplate jdbc;
    private final SchedulerLock lock;
    private final boolean enabled;

    public MealMenuNotifier(MenuService menus, NotificationService notifications, JdbcTemplate jdbc, SchedulerLock lock,
                            @Value("${app.push.meal-enabled:true}") boolean enabled) {
        this.menus = menus;
        this.notifications = notifications;
        this.jdbc = jdbc;
        this.lock = lock;
        this.enabled = enabled;
    }

    @Scheduled(cron = "${app.push.meal-cron:0 30 10 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        if (!enabled) {
            return;
        }
        try {
            // Gunde bir kez: kilit 20 saat tutulur (cok ornekte tek gonderim, yeniden baslatmada ikinci gonderim yok)
            lock.tryRun("meal-menu", Duration.ofHours(20), () -> run(LocalDate.now(ZONE)));
        } catch (RuntimeException e) {
            log.warn("Gunluk menu bildirimi calistirilamadi: {}", e.toString());
        }
    }

    /** @return bildirim yazilan kisi sayisi (menu yoksa 0) */
    int run(LocalDate today) {
        MenuResponse menu = menus.today().orElse(null);
        if (menu == null || !today.toString().equals(menu.date()) || menu.items() == null || menu.items().isEmpty()) {
            return 0;
        }
        Map<String, String> data = data(menu);
        String dishes = String.join(", ", menu.items());
        if (dishes.length() > 160) {
            dishes = dishes.substring(0, 159) + "…";
        }
        int sent = 0;
        long after = 0;
        for (int i = 0; i < MAX_PAGES; i++) {
            List<Long> ids = jdbc.queryForList("SELECT u.id FROM app_user u WHERE u.status = 'ACTIVE' AND u.id > ? AND NOT EXISTS (SELECT 1 FROM notification_pref p "
                    + "WHERE p.user_id = u.id AND p.meal_menu = FALSE) "
                    + "ORDER BY u.id LIMIT " + PAGE, Long.class, after);
            if (ids.isEmpty()) {
                break;
            }
            sent += notifications.sendTemplatedBulk(ids, TEMPLATE, data, "meal:" + today, dishes);
            after = ids.get(ids.size() - 1);
        }
        return sent;
    }

    /** Push yuku: hedef MEAL, tarih, (eksiksizse) toplam kalori, (varsa) menu gorseli. */
    static Map<String, String> data(MenuResponse menu) {
        Map<String, String> d = new LinkedHashMap<>();
        d.put("target", "MEAL");
        d.put("value", menu.date());
        d.put("mealDate", menu.date());
        if (menu.kcalComplete() && menu.totalKcal() != null) {
            d.put("totalKcal", String.valueOf(menu.totalKcal()));
        }
        String img = menu.imageUrl();
        if (img != null && !img.isBlank() && img.length() <= 300) {
            d.put("imageUrl", img);
        }
        return d;
    }
}
