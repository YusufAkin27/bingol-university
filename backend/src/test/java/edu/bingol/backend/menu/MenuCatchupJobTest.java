package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.status.StatusService;
import edu.bingol.backend.status.SyncStatus;
import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/**
 * P07-B2/K20: aylik menu cekimi ay sonunda basarisiz olursa bir ay beklenmesin. Gunluk 06:00 "yakalama":
 * ay yeterince doluysa kaynak siteye ISTEK ATMAZ; bos/eksikse en cok ~gunde bir kez dener.
 * Bakim bandi yalniz icinde bulunulan ayin menusu bossa gosterilir.
 */
class MenuCatchupJobTest {

    private static final ZoneId IST = ZoneId.of("Europe/Istanbul");
    /** 2026-11-03 06:00 Istanbul */
    private static final Instant NOW = LocalDate.of(2026, 11, 3).atTime(6, 0).atZone(IST).toInstant();

    private final MenuScraper scraper = mock(MenuScraper.class);
    private final MenuRepository repo = mock(MenuRepository.class);
    private final StatusService status = mock(StatusService.class);

    private MenuSyncService service(Instant now) {
        return new MenuSyncService(scraper, repo, status, new SyncProperties(false), Clock.fixed(now, IST));
    }

    private void monthHas(long days) {
        when(repo.countByMenuDateBetween(any(), any())).thenReturn(days);
    }

    private void lastAttempt(Instant at) {
        SyncStatus s = new SyncStatus();
        s.setSource(StatusService.MENU);
        s.setLastAttemptAt(at);
        when(status.find(StatusService.MENU)).thenReturn(Optional.of(s));
    }

    @Test
    void fullMonthMakesNoRequest() throws Exception {
        monthHas(22);
        lastAttempt(NOW.minusSeconds(3600L * 48));
        assertFalse(service(NOW).catchUp());
        verify(scraper, never()).fetch();
    }

    @Test
    void emptyMonthWithOldAttemptFetches() throws Exception {
        monthHas(0);
        lastAttempt(NOW.minusSeconds(3600L * 30));
        when(scraper.fetch()).thenReturn(List.of(new MenuScraper.Day(LocalDate.of(2026, 11, 3), List.of("Corba"))));
        when(repo.findByMenuDate(any())).thenReturn(Optional.empty());
        assertTrue(service(NOW).catchUp());
        verify(scraper).fetch();
    }

    @Test
    void recentAttemptIsRespected() throws Exception {
        monthHas(0);
        lastAttempt(NOW.minusSeconds(3600L * 5));
        assertFalse(service(NOW).catchUp());
        verify(scraper, never()).fetch();
    }

    @Test
    void neverAttemptedStillFetchesWhenMonthEmpty() throws Exception {
        monthHas(0);
        when(status.find(StatusService.MENU)).thenReturn(Optional.empty());
        when(scraper.fetch()).thenReturn(List.of());
        assertTrue(service(NOW).catchUp());
        verify(scraper).fetch();
    }

    @Test
    void partiallyFilledMonthIsRetriedOnlyInFirstWeek() throws Exception {
        monthHas(5);
        lastAttempt(NOW.minusSeconds(3600L * 48));
        when(scraper.fetch()).thenReturn(List.of());
        assertTrue(service(NOW).catchUp()); // 3 Kasim: ilk hafta
        Instant mid = LocalDate.of(2026, 11, 15).atTime(6, 0).atZone(IST).toInstant();
        assertFalse(service(mid).catchUp()); // 15 Kasim: az gun yayinlayan kaynagi her gun yoklama
    }

    @Test
    void failureKeepsStatusOkWhileCurrentMonthHasMenu() throws Exception {
        monthHas(10);
        when(scraper.fetch()).thenThrow(new IOException("zaman asimi"));
        assertEquals(-1, service(NOW).sync());
        verify(status, never()).markMaintenance(anyString(), any());
        verify(status).markAttempt(eq(StatusService.MENU), anyString());
    }

    @Test
    void failureShowsMaintenanceWhenCurrentMonthEmpty() throws Exception {
        monthHas(0);
        when(scraper.fetch()).thenThrow(new IOException("zaman asimi"));
        assertEquals(-1, service(NOW).sync());
        verify(status).markMaintenance(eq(StatusService.MENU), anyString());
    }

    @Test
    void emptyScrapeResultFollowsSameRule() throws Exception {
        monthHas(10);
        when(scraper.fetch()).thenReturn(List.of());
        assertEquals(-1, service(NOW).sync());
        verify(status, never()).markMaintenance(anyString(), any());
        verify(status).markAttempt(eq(StatusService.MENU), anyString());
    }
}
