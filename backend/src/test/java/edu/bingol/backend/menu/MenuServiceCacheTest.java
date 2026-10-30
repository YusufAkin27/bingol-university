package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Yemek listesi sunucu onbellegi: ay ve bugun onbellekten, kalori/menu yazmasinda (ad alani) yenilenir. */
class MenuServiceCacheTest {

    private final MenuRepository repo = mock(MenuRepository.class);
    private final MenuCalorieService calories = mock(MenuCalorieService.class);
    private final CacheService cache = TestCaches.create();
    private final MenuService service = new MenuService(repo, calories);
    private final LocalDate today = LocalDate.now(ZoneId.of("Europe/Istanbul"));

    private MenuDay day(LocalDate d, String items) {
        MenuDay m = new MenuDay();
        m.setMenuDate(d);
        m.setItems(items);
        return m;
    }

    @BeforeEach
    void wire() {
        service.setCache(cache);
        when(repo.findByMenuDateBetweenOrderByMenuDate(any(), any())).thenReturn(List.of(day(today, "Corba\nPilav")));
        when(calories.range(any(), any())).thenReturn(Map.of(today, Map.of(MenuItemKey.of("Corba"), 120)));
        when(repo.findByMenuDate(today)).thenReturn(Optional.of(day(today, "Corba\nPilav")));
        when(calories.forDate(today)).thenReturn(Map.of(MenuItemKey.of("Corba"), 120));
    }

    @Test
    void monthIsLoadedOnceAndKeepsCalories() {
        YearMonth ym = YearMonth.from(today);
        List<MenuResponse> a = service.month(ym);
        List<MenuResponse> b = service.month(ym);
        verify(repo, times(1)).findByMenuDateBetweenOrderByMenuDate(any(), any());
        assertEquals(a, b);
        assertEquals(120, b.get(0).dishes().get(0).kcal());
        service.month(ym.plusMonths(1));
        verify(repo, times(2)).findByMenuDateBetweenOrderByMenuDate(any(), any());
    }

    @Test
    void todayIsCachedAndCalorieEditShowsAfterInvalidation() {
        assertEquals(120, service.today().orElseThrow().dishes().get(0).kcal());
        service.today();
        verify(repo, times(1)).findByMenuDate(today);

        when(calories.forDate(today)).thenReturn(Map.of(MenuItemKey.of("Corba"), 200));
        assertEquals(120, service.today().orElseThrow().dishes().get(0).kcal(), "gecersiz kilinmeden onbellek sunulur");
        cache.invalidate("menu");
        assertEquals(200, service.today().orElseThrow().dishes().get(0).kcal());
    }

    @Test
    void missingMenuForTodayIsNegativeCachedBriefly() {
        when(repo.findByMenuDate(today)).thenReturn(Optional.empty());
        assertTrue(service.today().isEmpty());
        assertTrue(service.today().isEmpty());
        verify(repo, times(1)).findByMenuDate(today);
    }

    @Test
    void responsesSurviveJsonRoundTripThroughRedis() {
        CacheService[] p = TestCaches.pair();
        MenuService a = new MenuService(repo, calories);
        a.setCache(p[0]);
        MenuService b = new MenuService(repo, calories);
        b.setCache(p[1]);
        YearMonth ym = YearMonth.from(today);
        assertEquals(a.month(ym), b.month(ym));
        assertEquals(a.today(), b.today());
        verify(repo, times(1)).findByMenuDateBetweenOrderByMenuDate(any(), any());
        verify(repo, times(1)).findByMenuDate(today);
    }
}
