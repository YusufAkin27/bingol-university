package edu.bingol.backend.news;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.status.StatusService;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;

/** T-074 (A2-18): kaynak site cok yavassa senkron toplam sure butcesinde kesilir ve bakim isaretlenir. */
class NewsSyncBudgetTest {

    private final NewsScraper scraper = mock(NewsScraper.class);
    private final NewsRepository repo = mock(NewsRepository.class);
    private final StatusService status = mock(StatusService.class);
    private final NewsSyncService sync = new NewsSyncService(scraper, repo, status, mock(SyncProperties.class),
            mock(NotificationService.class), mock(I18n.class));

    @Test
    void exceededBudgetStopsFetchingAndMarksMaintenance() throws IOException {
        when(repo.count()).thenReturn(5L);
        for (ContentType t : ContentType.values()) {
            when(scraper.fetchList(t)).thenReturn(List.of(
                    new NewsScraper.ListEntry("https://www.bingol.edu.tr/" + t + "/1", "Baslik", null)));
        }
        when(repo.findContentRetryCandidates(anyInt(), any(Instant.class), any(Pageable.class))).thenReturn(List.of());
        sync.setBudget(Duration.ZERO); // en basta asildi

        sync.sync();

        verify(scraper, never()).fetchDetail(anyString());
        verify(repo, never()).save(any(NewsItem.class));
        verify(status).markMaintenance(org.mockito.ArgumentMatchers.eq(StatusService.NEWS), anyString());
        verify(status, never()).markOk(org.mockito.ArgumentMatchers.eq(StatusService.NEWS), any());
    }

    @Test
    void withinBudgetBehavesAsBefore() throws IOException {
        when(repo.count()).thenReturn(5L);
        for (ContentType t : ContentType.values()) {
            when(scraper.fetchList(t)).thenReturn(List.of());
        }
        // bos listeler -> tum turler basarisiz sayilir: bakim (butce nedeniyle degil)
        sync.sync();
        verify(status).markMaintenance(org.mockito.ArgumentMatchers.eq(StatusService.NEWS), org.mockito.ArgumentMatchers.contains("Kaynak site okunamadi"));
    }
}
