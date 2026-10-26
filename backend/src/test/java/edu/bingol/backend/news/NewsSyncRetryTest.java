package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.status.StatusService;
import java.io.IOException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Pageable;

class NewsSyncRetryTest {

    private final NewsScraper scraper = mock(NewsScraper.class);
    private final NewsRepository repo = mock(NewsRepository.class);
    private final StatusService status = mock(StatusService.class);
    private final NewsSyncService sync = new NewsSyncService(scraper, repo, status, mock(SyncProperties.class),
            mock(NotificationService.class), mock(I18n.class));

    private static NewsItem item(ContentType type, String url) {
        NewsItem n = new NewsItem();
        n.setType(type);
        n.setUrl(url);
        n.setTitle("t");
        n.setContentAttempts(1);
        return n;
    }

    private void listsFail() throws IOException {
        for (ContentType t : ContentType.values()) {
            when(scraper.fetchList(t)).thenThrow(new IOException("down"));
        }
    }

    @Test
    void newItemWithUndatedRowGetsFetchDayAndAttemptCounted() throws IOException {
        when(repo.count()).thenReturn(5L);
        for (ContentType t : ContentType.values()) {
            when(scraper.fetchList(t)).thenReturn(t == ContentType.HABER
                    ? List.of(new NewsScraper.ListEntry("https://www.bingol.edu.tr/h/1", "Baslik", null))
                    : List.of());
        }
        when(scraper.fetchDetail("https://www.bingol.edu.tr/h/1")).thenReturn(null);
        when(repo.save(any(NewsItem.class))).thenAnswer(i -> i.getArgument(0));

        sync.sync();

        ArgumentCaptor<NewsItem> cap = ArgumentCaptor.forClass(NewsItem.class);
        verify(repo).save(cap.capture());
        assertNotNull(cap.getValue().getPublishedDate());
        assertEquals(1, cap.getValue().getContentAttempts());
        assertNull(cap.getValue().getContent());
    }

    @Test
    void retryFillsMissingContentAndStoresEventDate() throws IOException {
        NewsItem ev = item(ContentType.ETKINLIK, "https://www.bingol.edu.tr/e/1");
        when(repo.count()).thenReturn(5L);
        when(repo.findContentRetryCandidates(anyInt(), any(Instant.class), any(Pageable.class))).thenReturn(List.of(ev));
        listsFail();
        when(scraper.fetchDetail(ev.getUrl()))
                .thenReturn(new NewsScraper.Detail("Etkinlik Tarihi: 12.11.2026", null, LocalDate.of(2026, 11, 12)));

        sync.sync();

        assertEquals("Etkinlik Tarihi: 12.11.2026", ev.getContent());
        assertEquals(LocalDate.of(2026, 11, 12), ev.getEventDate());
        assertEquals(2, ev.getContentAttempts());
        verify(repo).save(ev);
    }

    @Test
    void failedRetryOnlyIncrementsAttempts() throws IOException {
        NewsItem n = item(ContentType.HABER, "https://www.bingol.edu.tr/h/2");
        when(repo.count()).thenReturn(5L);
        when(repo.findContentRetryCandidates(anyInt(), any(Instant.class), any(Pageable.class))).thenReturn(List.of(n));
        listsFail();
        when(scraper.fetchDetail(n.getUrl())).thenReturn(null);

        sync.sync();

        assertNull(n.getContent());
        assertEquals(2, n.getContentAttempts());
        assertNotNull(n.getContentAttemptedAt());
        verify(status, never()).markOk(any(), any());
    }
}
