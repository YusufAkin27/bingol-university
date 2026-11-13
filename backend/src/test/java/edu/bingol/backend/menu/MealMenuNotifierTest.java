package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppSetting;
import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.menu.dto.MenuDish;
import edu.bingol.backend.menu.dto.MenuResponse;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.support.ResourceBundleMessageSource;

/**
 * Gunun menusu push'u: yuk, govde kisaltma, gunluk idempotens, telafi penceresi, menu yok, yonetici ayari. Kuyruga yazim
 * (alici suzgeci/parcalama) {@link NotificationService#pushOnlyBroadcastLocalized} icindedir ve PostgreSQL duman
 * betigiyle dogrulanir; burada cagrinin tek kez ve dogru metinle yapildigi denetlenir.
 */
class MealMenuNotifierTest {

    /** 2026-11-09 Pazartesi, Istanbul saatine gore. */
    private static Clock at(String istanbulLocal) {
        java.time.ZoneId zone = java.time.ZoneId.of("Europe/Istanbul");
        Instant t = java.time.ZonedDateTime.of(LocalDate.of(2026, 11, 9), java.time.LocalTime.parse(istanbulLocal), zone)
                .toInstant();
        return Clock.fixed(t, zone);
    }

    private static MenuResponse menu(Integer total, boolean complete, String image) {
        return new MenuResponse("2026-11-09", List.of("Mercimek", "Pilav"), image,
                List.of(new MenuDish("Mercimek", 100), new MenuDish("Pilav", complete ? 200 : null)), total, complete);
    }

    private static MenuResponse menuOf(List<String> names, Integer total, boolean complete) {
        return new MenuResponse("2026-11-09", names, null, names.stream().map(n -> new MenuDish(n, null)).toList(), total,
                complete);
    }

    /** Bellek ici gunluk kayit: birincil anahtar semantigi. */
    static class FakeLog implements DailyMenuLog {
        final Map<LocalDate, String> rows = new HashMap<>();
        final Map<LocalDate, Integer> counts = new HashMap<>();

        @Override
        public boolean exists(LocalDate day) {
            return rows.containsKey(day);
        }

        @Override
        public boolean claim(LocalDate day, String outcome) {
            return rows.putIfAbsent(day, outcome) == null;
        }

        @Override
        public void finish(LocalDate day, String outcome, int enqueued) {
            rows.put(day, outcome);
            counts.put(day, enqueued);
        }
    }

    private I18n i18n;
    private MenuService menus;
    private NotificationService notifications;
    private AppSettingRepository settings;
    private FakeLog log;

    @BeforeEach
    void setUp() {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/messages");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        i18n = new I18n(ms, mock(UserRepository.class));
        menus = mock(MenuService.class);
        notifications = mock(NotificationService.class);
        settings = mock(AppSettingRepository.class);
        log = new FakeLog();
        when(settings.findById(anyString())).thenReturn(Optional.empty());
    }

    private MealMenuNotifier notifier(String time) {
        return new MealMenuNotifier(menus, notifications, log, null, settings, i18n, true, at(time));
    }

    @Test
    void queuesOnceWhenMenuExists() {
        when(menus.today()).thenReturn(Optional.of(menu(300, true, null)));
        when(notifications.pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any())).thenReturn(42);
        MealMenuNotifier n = notifier("11:30:00");

        assertEquals(42, n.attempt(false));
        verify(notifications).pushOnlyBroadcastLocalized(eq(NotificationType.ANNOUNCEMENT), eq(NotificationSubtype.MEAL_MENU),
                eq("meal_menu"), any(), any(), any());
        assertEquals("QUEUED", log.rows.get(LocalDate.of(2026, 11, 9)));
        assertEquals(42, log.counts.get(LocalDate.of(2026, 11, 9)));

        // ayni gun ikinci calistirma (yeniden baslatma / ikinci ornek / telafi tetigi): hicbir sey yazmaz
        assertEquals(0, n.attempt(false));
        assertEquals(0, notifier("11:45:00").attempt(true));
        assertEquals(0, notifier("11:30:00").attempt(false));
        verify(notifications, times(1)).pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    void noMenuSendsNothingAndMarksDay() {
        when(menus.today()).thenReturn(Optional.empty());
        MealMenuNotifier n = notifier("11:30:00");
        assertEquals(0, n.attempt(false));
        assertEquals("NO_MENU", log.rows.get(LocalDate.of(2026, 11, 9)));
        verify(notifications, never()).pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any());

        // menu sonradan belirse bile telafi calismaz (gun zaten denendi)
        when(menus.today()).thenReturn(Optional.of(menu(300, true, null)));
        assertEquals(0, notifier("12:00:00").attempt(true));
        verify(notifications, never()).pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    void staleMenuDateIsTreatedAsNoMenu() {
        when(menus.today()).thenReturn(Optional.of(new MenuResponse("2026-11-08", List.of("Pilav"), null, List.of(), null, false)));
        assertEquals(0, notifier("11:30:00").attempt(false));
        verify(notifications, never()).pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    void catchUpOnlyInsideWindowAndWhenMissed() {
        when(menus.today()).thenReturn(Optional.of(menu(null, false, null)));
        when(notifications.pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any())).thenReturn(5);

        assertEquals(0, notifier("11:15:00").attempt(true), "11:30 oncesi telafi yok");
        assertEquals(0, notifier("14:00:00").attempt(true), "14:00 ve sonrasi telafi yok");
        assertEquals(0, notifier("16:00:00").attempt(true));
        assertTrue(log.rows.isEmpty());

        assertEquals(5, notifier("12:15:00").attempt(true), "kacirilan calisma pencere icinde telafi edilir");
        assertEquals(0, notifier("12:30:00").attempt(true));
        verify(notifications, times(1)).pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    void adminSettingOffSkipsWithoutClaimingDay() {
        AppSetting off = new AppSetting();
        off.setKey("daily_menu_push_enabled");
        off.setValue("false");
        when(settings.findById("daily_menu_push_enabled")).thenReturn(Optional.of(off));
        when(menus.today()).thenReturn(Optional.of(menu(null, false, null)));
        assertEquals(0, notifier("11:30:00").attempt(false));
        assertTrue(log.rows.isEmpty());
        verify(notifications, never()).pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    void failureIsNotRetriedSameDay() {
        when(menus.today()).thenReturn(Optional.of(menu(null, false, null)));
        when(notifications.pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any()))
                .thenThrow(new IllegalStateException("db"));
        assertEquals(0, notifier("11:30:00").attempt(false));
        assertEquals("FAILED", log.rows.get(LocalDate.of(2026, 11, 9)));
        assertEquals(0, notifier("12:00:00").attempt(true));
        verify(notifications, times(1)).pushOnlyBroadcastLocalized(any(), any(), any(), any(), any(), any());
    }

    @Test
    @SuppressWarnings("unchecked")
    void textIsBuiltPerRecipientLanguage() {
        when(menus.today()).thenReturn(Optional.of(menuOf(List.of("Mercimek", "Pilav", "Tavuk", "Salata", "Ayran"), 950, true)));
        notifier("11:30:00").attempt(false);
        ArgumentCaptor<Function<Lang, String>> title = ArgumentCaptor.forClass(Function.class);
        ArgumentCaptor<Function<Lang, String>> body = ArgumentCaptor.forClass(Function.class);
        verify(notifications).pushOnlyBroadcastLocalized(any(), any(), any(), title.capture(), body.capture(), any());

        assertEquals("Günün menüsü", title.getValue().apply(Lang.TR));
        assertEquals("Menu of the day", title.getValue().apply(Lang.EN));
        assertEquals("Mercimek, Pilav, Tavuk, Salata… · toplam 950 kcal", body.getValue().apply(Lang.TR));
        assertEquals("Mercimek, Pilav, Tavuk, Salata… · total 950 kcal", body.getValue().apply(Lang.EN));
        assertTrue(body.getValue().apply(Lang.AR).contains("950"));
    }

    @Test
    void longMenuIsTruncatedToLimit() {
        List<String> names = new ArrayList<>();
        for (int i = 0; i < 4; i++) {
            names.add("Cok uzun bir yemek adi ".repeat(4).trim() + i);
        }
        String b = MealMenuNotifier.body(menuOf(names, 1234, true), Lang.TR, i18n);
        assertTrue(b.length() <= MealMenuNotifier.MAX_BODY, "govde " + b.length() + " karakter");
        assertTrue(b.endsWith("toplam 1234 kcal"), "kalori kisaltmada korunur: " + b);
        assertTrue(b.contains("…"));
    }

    @Test
    void bodyWithoutCompleteKcalHasNoTotal() {
        String b = MealMenuNotifier.body(menuOf(List.of("Mercimek", "Pilav"), 100, false), Lang.TR, i18n);
        assertEquals("Mercimek, Pilav", b);
    }

    @Test
    void totalKcalOnlyWhenComplete() {
        Map<String, String> d = MealMenuNotifier.data(menu(300, true, null));
        assertEquals("MEAL", d.get("target"));
        assertEquals("2026-11-09", d.get("value"));
        assertEquals("2026-11-09", d.get("mealDate"));
        assertEquals("300", d.get("totalKcal"));

        Map<String, String> partial = MealMenuNotifier.data(menu(100, false, null));
        assertFalse(partial.containsKey("totalKcal"), "eksik kalori toplami gosterilmez");
    }

    @Test
    void imageOnlyWhenMenuHasContentImage() {
        assertFalse(MealMenuNotifier.data(menu(null, false, null)).containsKey("imageUrl"));
        assertFalse(MealMenuNotifier.data(menu(null, false, "  ")).containsKey("imageUrl"));
        assertEquals("/files/menu/1.jpg", MealMenuNotifier.data(menu(null, false, "/files/menu/1.jpg")).get("imageUrl"));
    }
}
