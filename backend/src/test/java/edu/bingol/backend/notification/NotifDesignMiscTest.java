package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.menu.MenuDailyNotifier;
import edu.bingol.backend.menu.MenuService;
import edu.bingol.backend.menu.dto.MenuDish;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Pageable;

/** Tasarim bildirimi yardimci/kucuk parcalari: gunluk menu, apns yuku, cihaz modeli, kisaltma. */
class NotifDesignMiscTest {

    private static MenuResponse menu(Integer total, boolean complete, String image) {
        return new MenuResponse("2026-11-02", List.of("Mercimek Çorbası", "Orman Kebabı", "Pilav"), image,
                List.of(new MenuDish("Mercimek Çorbası", 120), new MenuDish("Orman Kebabı", 400), new MenuDish("Pilav", 300)),
                total, complete);
    }

    @Test
    void dailyMenuSendsToOptedInUsersWithKcalAndImageFromDbMenuOnly() {
        MenuService ms = mock(MenuService.class);
        NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
        NotificationService ns = mock(NotificationService.class);
        when(ms.today()).thenReturn(Optional.of(menu(820, true, "/files/menu/1.jpg")));
        when(prefs.menuDailyUserIds(org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.any(Pageable.class)))
                .thenReturn(List.of(4L, 9L));

        new MenuDailyNotifier(ms, prefs, ns).run();

        ArgumentCaptor<NotificationTemplates.Template> t = ArgumentCaptor.forClass(NotificationTemplates.Template.class);
        ArgumentCaptor<Map<String, String>> data = ArgumentCaptor.forClass(Map.class);
        verify(ns).sendTemplatedBulk(eq(List.of(4L, 9L)), t.capture(), data.capture(), eq("menu:2026-11-02"),
                eq("Mercimek Çorbası, Orman Kebabı, Pilav"), eq("820"));
        assertEquals("notif.menu.today", t.getValue().key());
        assertEquals(NotificationSubtype.MENU_DAILY, t.getValue().subtype());
        assertEquals("/files/menu/1.jpg", data.getValue().get("imageUrl"));
        assertEquals("2026-11-02", data.getValue().get("menuDate"));
    }

    @Test
    void dailyMenuUsesPartialTemplateWhenKcalIncompleteAndSkipsWhenNoMenu() {
        MenuService ms = mock(MenuService.class);
        NotificationPrefRepository prefs = mock(NotificationPrefRepository.class);
        NotificationService ns = mock(NotificationService.class);
        when(prefs.menuDailyUserIds(org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.any(Pageable.class)))
                .thenReturn(List.of(4L));
        when(ms.today()).thenReturn(Optional.empty());
        assertEquals(0, new MenuDailyNotifier(ms, prefs, ns).run());
        verify(ns, never()).sendTemplatedBulk(anyCollection(), org.mockito.ArgumentMatchers.any(NotificationTemplates.Template.class),
                anyMap(), anyString(), anyString(), anyString());

        when(ms.today()).thenReturn(Optional.of(menu(520, false, null)));
        new MenuDailyNotifier(ms, prefs, ns).run();
        ArgumentCaptor<NotificationTemplates.Template> t = ArgumentCaptor.forClass(NotificationTemplates.Template.class);
        ArgumentCaptor<Map<String, String>> data = ArgumentCaptor.forClass(Map.class);
        verify(ns).sendTemplatedBulk(anyCollection(), t.capture(), data.capture(), anyString(), anyString(), anyString());
        assertEquals("notif.menu.todayPartial", t.getValue().key());
        assertFalse(data.getValue().containsKey("imageUrl"));
    }

    @Test
    void dishLineIsCappedAndNamesAreNotTranslated() {
        MenuResponse many = new MenuResponse("2026-11-02", List.of("a", "b", "c", "d", "e", "f"), null,
                List.of(), null, false);
        assertEquals("a, b, c, d, e…", MenuDailyNotifier.dishLine(many));
    }
}
