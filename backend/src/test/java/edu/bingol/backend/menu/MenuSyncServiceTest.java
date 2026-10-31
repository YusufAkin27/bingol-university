package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.status.StatusService;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** T-050: 1000 karakteri asan gun tum senkronu bozmaz; hatali gun atlanir, digerleri islenir. */
class MenuSyncServiceTest {

    @Test
    void overlongDayIsCutAndOtherDaysStillSaved() throws Exception {
        MenuScraper scraper = mock(MenuScraper.class);
        MenuRepository repo = mock(MenuRepository.class);
        StatusService status = mock(StatusService.class);
        SyncProperties props = new SyncProperties(false);

        List<String> huge = new ArrayList<>();
        for (int i = 0; i < 200; i++) {
            huge.add("Cok uzun yemek adi numara " + i);
        }
        LocalDate d1 = LocalDate.of(2026, 10, 1);
        LocalDate d2 = LocalDate.of(2026, 10, 2);
        when(scraper.fetch()).thenReturn(List.of(
                new MenuScraper.Day(d1, huge), new MenuScraper.Day(d2, List.of("Corba", "Pilav"))));
        when(repo.findByMenuDate(any())).thenReturn(Optional.empty());

        int changed = new MenuSyncService(scraper, repo, status, props).sync();

        assertEquals(2, changed);
        ArgumentCaptor<MenuDay> cap = ArgumentCaptor.forClass(MenuDay.class);
        verify(repo, org.mockito.Mockito.times(2)).save(cap.capture());
        assertTrue(cap.getAllValues().get(0).getItems().length() <= 1000);
        verify(status).markOk(StatusService.MENU, null);
        verify(status, never()).markMaintenance(any(), any());
    }

    @Test
    void failingDayIsSkippedNotMaintenance() throws Exception {
        MenuScraper scraper = mock(MenuScraper.class);
        MenuRepository repo = mock(MenuRepository.class);
        StatusService status = mock(StatusService.class);
        SyncProperties props = new SyncProperties(false);

        LocalDate d1 = LocalDate.of(2026, 10, 1);
        LocalDate d2 = LocalDate.of(2026, 10, 2);
        when(scraper.fetch()).thenReturn(List.of(
                new MenuScraper.Day(d1, List.of("A")), new MenuScraper.Day(d2, List.of("B"))));
        when(repo.findByMenuDate(any())).thenReturn(Optional.empty());
        when(repo.save(any(MenuDay.class)))
                .thenThrow(new IllegalStateException("kisit ihlali"))
                .thenAnswer(inv -> inv.getArgument(0));

        int changed = new MenuSyncService(scraper, repo, status, props).sync();

        assertEquals(1, changed);
        verify(status).markOk(StatusService.MENU, null);
        verify(status, never()).markMaintenance(any(), any());
    }
}
