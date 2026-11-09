package edu.bingol.backend.menu;

import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.menu.dto.MenuResponse;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gunun menusu push'u: her gun 11:30'da (Europe/Istanbul), YALNIZ o gun icin menu varsa, gunde EN FAZLA BIR kez, tum aktif
 * kullanicilarin cihazlarina KALICI push kuyrugu ({@code push_outbox}) uzerinden. Uygulama ici bildirim kutusuna yazmaz.
 * Gonderimi {@code PushOutboxWorker} yapar (FCM parcalari, yeniden deneme, gecersiz token silme).
 *
 * <p>Idempotens: {@link DailyMenuLog#claim} gunu birincil anahtarla sahiplenir; yeniden baslatma ya da ikinci ornek
 * ayni gun ikinci gonderim yapamaz (kuyruga yazarken cokerse o gun KAYBOLUR, cift gonderimden iyidir). 11:30 kacirilirsa
 * (sunucu kapali) telafi tetigi 11:30-14:00 arasi yalniz gun hic denenmediyse bir kez gonderir. Menu yoksa gun
 * {@code NO_MENU} olarak kayda gecer ve telafi de calismaz. Tercih {@code notification_pref.meal_menu} (varsayilan acik);
 * hesap ACTIVE olmali; sessiz saatteki kullanici atlanir. Yonetici {@code app_setting.daily_menu_push_enabled=false} ile
 * kapatabilir. Kaynak siteye istek atmaz. Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class MealMenuNotifier {

    private static final Logger log = LoggerFactory.getLogger(MealMenuNotifier.class);
    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    static final String SETTING_KEY = "daily_menu_push_enabled";
    /** notification_pref sutunu. */
    static final String PREF_COLUMN = "meal_menu";
    /** Telafi penceresi: [11:30, 14:00). */
    static final LocalTime WINDOW_START = LocalTime.of(11, 30);
    static final LocalTime WINDOW_END = LocalTime.of(14, 0);
    /** Gorunen yemek adi sayisi ve push govde sinirinin (karakter) ustu. */
    static final int MAX_DISHES = 4;
    static final int MAX_BODY = 150;

    private final MenuService menus;
    private final NotificationService notifications;
    private final DailyMenuLog dayLog;
    private final SchedulerLock lock;
    private final AppSettingRepository settings;
    private final I18n i18n;
    private final Clock clock;
    private final boolean enabled;

    @Autowired
    public MealMenuNotifier(MenuService menus, NotificationService notifications, DailyMenuLog dayLog, SchedulerLock lock,
                            AppSettingRepository settings, I18n i18n,
                            @Value("${app.push.daily-menu-enabled:true}") boolean enabled) {
        this(menus, notifications, dayLog, lock, settings, i18n, enabled, Clock.system(ZONE));
    }

    MealMenuNotifier(MenuService menus, NotificationService notifications, DailyMenuLog dayLog, SchedulerLock lock,
                     AppSettingRepository settings, I18n i18n, boolean enabled, Clock clock) {
        this.menus = menus;
        this.notifications = notifications;
        this.dayLog = dayLog;
        this.lock = lock;
        this.settings = settings;
        this.i18n = i18n;
        this.enabled = enabled;
        this.clock = clock;
    }

    /** Ana tetik: her gun 11:30. */
    @Scheduled(cron = "${app.push.daily-menu-cron:0 30 11 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        guarded(false);
    }

    /** Telafi tetigi: 15 dk'da bir (11:00-13:45), yalniz [11:30, 14:00) icinde ve gun denenmediyse calisir. */
    @Scheduled(cron = "${app.push.daily-menu-catchup-cron:0 0/15 11-13 * * *}", zone = "Europe/Istanbul")
    public void catchUp() {
        guarded(true);
    }

    private void guarded(boolean catchUp) {
        if (!enabled) {
            return;
        }
        try {
            // Kilit yalniz eszamanli calismayi onler; asil tekillik gunluk kayittadir
            lock.tryRun("daily-menu-push", Duration.ofMinutes(10), () -> attempt(catchUp));
        } catch (RuntimeException e) {
            log.warn("Gunun menusu bildirimi calistirilamadi: {}", e.toString());
        }
    }

    /**
     * @param catchUp true ise yalniz [11:30, 14:00) penceresinde ve gun hic denenmediyse calisir
     * @return kuyruga yazilan cihaz sayisi (menu yok / zaten denendi / kapali = 0)
     */
    int attempt(boolean catchUp) {
        ZonedDateTime now = ZonedDateTime.now(clock);
        LocalDate today = now.toLocalDate();
        if (catchUp && (now.toLocalTime().isBefore(WINDOW_START) || !now.toLocalTime().isBefore(WINDOW_END))) {
            return 0;
        }
        if (!settingOn()) {
            log.info("Gunun menusu bildirimi yonetici ayariyla kapali ({})", today);
            return 0;
        }
        if (dayLog.exists(today)) {
            return 0;
        }
        MenuResponse menu = menus.today().orElse(null);
        if (menu == null || !today.toString().equals(menu.date()) || menu.items() == null || menu.items().isEmpty()) {
            if (dayLog.claim(today, "NO_MENU")) {
                log.info("Gunun menusu bildirimi: {} icin menu yok, gonderilmedi", today);
            }
            return 0;
        }
        if (!dayLog.claim(today, "QUEUED")) {
            return 0; // baska ornek / onceki calisma sahiplendi
        }
        int queued = 0;
        try {
            Map<String, String> data = data(menu);
            queued = notifications.pushOnlyBroadcastLocalized(NotificationType.ANNOUNCEMENT, NotificationSubtype.MEAL_MENU,
                    PREF_COLUMN, lang -> i18n.msg("notif.meal.today.title", lang), lang -> body(menu, lang, i18n), data);
            dayLog.finish(today, "QUEUED", queued);
            log.info("Gunun menusu bildirimi: {} icin {} cihaz kuyruga yazildi ({} yemek)", today, queued,
                    menu.items().size());
        } catch (RuntimeException e) {
            log.warn("Gunun menusu bildirimi kuyruga yazilamadi ({}): {}", today, e.toString());
            try {
                dayLog.finish(today, "FAILED", queued);
            } catch (RuntimeException ignored) {
                // kayit guncellenemedi: gun zaten sahiplenilmis, yeniden denenmez
            }
        }
        return queued;
    }

    private boolean settingOn() {
        try {
            return settings.findById(SETTING_KEY).map(s -> !"false".equalsIgnoreCase(s.getValue().trim())).orElse(true);
        } catch (RuntimeException e) {
            return true;
        }
    }

    /** Push govdesi: ilk {@link #MAX_DISHES} yemek (kaynaktan oldugu gibi, cevrilmez) + biliniyorsa toplam kalori; en cok {@link #MAX_BODY} karakter. */
    static String body(MenuResponse menu, Lang lang, I18n i18n) {
        List<String> names = new ArrayList<>();
        for (String n : menu.items()) {
            if (n != null && !n.isBlank()) {
                names.add(n.trim());
            }
        }
        String dishes = String.join(", ", names.subList(0, Math.min(MAX_DISHES, names.size())));
        if (names.size() > MAX_DISHES) {
            dishes += "…";
        }
        String kcal = "";
        if (menu.kcalComplete() && menu.totalKcal() != null) {
            kcal = " · " + i18n.msg("notif.meal.today.kcal", lang, String.valueOf(menu.totalKcal()));
        }
        int room = MAX_BODY - kcal.length();
        if (dishes.length() > room) {
            dishes = dishes.substring(0, Math.max(0, room - 1)).stripTrailing() + "…";
        }
        return dishes + kcal;
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
