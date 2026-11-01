package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SyncProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.status.StatusService;
import edu.bingol.backend.status.SyncStatus;
import edu.bingol.backend.status.SyncStatusRepository;
import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * P07-B7/B8/B13: haber senkronunda ortada hata olsa bile o ana dek eklenenler icin bildirim gider; kesinti bayragi
 * korunur; sync_status mesaji 500 karakterle sinirlanir; kaynak site yonlendirmeleri yalniz ayni ana siteye izlenir.
 */
class NewsSyncFailureHandlingTest {

    private final NewsScraper scraper = mock(NewsScraper.class);
    private final NewsRepository repo = mock(NewsRepository.class);
    private final StatusService status = mock(StatusService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final NewsSyncService sync = new NewsSyncService(scraper, repo, status, mock(SyncProperties.class),
            notifications, mock(I18n.class));

    private void onlyHaberWith(String... urls) throws IOException {
        when(repo.count()).thenReturn(5L);
        for (ContentType t : ContentType.values()) {
            when(scraper.fetchList(t)).thenReturn(t == ContentType.HABER
                    ? java.util.Arrays.stream(urls).map(u -> new NewsScraper.ListEntry(u, "Baslik " + u, LocalDate.now())).toList()
                    : List.of());
        }
        when(repo.save(any(NewsItem.class))).thenAnswer(i -> {
            NewsItem n = i.getArgument(0);
            n.setId((long) n.getUrl().hashCode());
            return n;
        });
    }

    @Test
    void itemsSavedBeforeAMidRunFailureStillGetNotified() throws Exception {
        onlyHaberWith("https://www.bingol.edu.tr/h/1", "https://www.bingol.edu.tr/h/2");
        when(scraper.fetchDetail("https://www.bingol.edu.tr/h/1")).thenReturn(null);
        when(scraper.fetchDetail("https://www.bingol.edu.tr/h/2")).thenThrow(new IllegalStateException("db down"));

        sync.sync();

        ArgumentCaptor<String> title = ArgumentCaptor.forClass(String.class);
        verify(notifications, times(1)).broadcast(eq(NotificationType.NEWS), title.capture(), any(), any());
        assertEquals("Baslik https://www.bingol.edu.tr/h/1", title.getValue());
    }

    @Test
    void noNotificationWhenNothingWasSavedBeforeTheFailure() throws Exception {
        onlyHaberWith("https://www.bingol.edu.tr/h/1");
        when(scraper.fetchDetail(anyString())).thenThrow(new IllegalStateException("db down"));

        sync.sync();

        verify(notifications, never()).broadcast(any(), anyString(), any(), any());
    }

    @Test
    void interruptionIsRestoredAndRemainingTypesAreSkipped() throws Exception {
        onlyHaberWith("https://www.bingol.edu.tr/h/1");
        when(scraper.fetchDetail(anyString())).thenReturn(null);
        Thread.currentThread().interrupt(); // Thread.sleep ilk kayittan sonra InterruptedException atar
        try {
            sync.sync();
            assertTrue(Thread.currentThread().isInterrupted(), "kesinti bayragi geri konmali");
            verify(scraper, never()).fetchList(ContentType.ETKINLIK); // HABER'den sonraki tur calismaz
        } finally {
            Thread.interrupted(); // sonraki testleri etkilemesin
        }
    }

    @Test
    void statusMessageIsClippedTo500Characters() {
        SyncStatusRepository repoStatus = mock(SyncStatusRepository.class);
        when(repoStatus.findById("NEWS")).thenReturn(Optional.empty());
        StatusService real = new StatusService(repoStatus);

        real.markMaintenance(StatusService.NEWS, "x".repeat(900));
        real.markOk(StatusService.NEWS, "y".repeat(900));
        real.markAttempt(StatusService.NEWS, "z".repeat(900));

        ArgumentCaptor<SyncStatus> cap = ArgumentCaptor.forClass(SyncStatus.class);
        verify(repoStatus, times(3)).save(cap.capture());
        cap.getAllValues().forEach(s -> assertEquals(500, s.getMessage().length()));
    }

    @Test
    void redirectsOnlyFollowToSameMainSiteOverHttps() throws Exception {
        assertEquals("https://www.bingol.edu.tr/yeni/yol?a=1",
                NewsScraper.nextHop("https://www.bingol.edu.tr/eski", "/yeni/yol?a=1"));
        assertEquals("https://www.bingol.edu.tr/x", NewsScraper.nextHop("https://www.bingol.edu.tr/a",
                "http://www.bingol.edu.tr/x"), "http -> https");
        assertThrows(IOException.class, () -> NewsScraper.nextHop("https://www.bingol.edu.tr/a", "https://evil.example/x"));
        assertThrows(IOException.class, () -> NewsScraper.nextHop("https://www.bingol.edu.tr/a", "https://sks.bingol.edu.tr/x"));
        assertThrows(IOException.class, () -> NewsScraper.nextHop("https://www.bingol.edu.tr/a", "https://www.bingol.edu.tr:8443/x"));
        assertThrows(IOException.class, () -> NewsScraper.nextHop("https://www.bingol.edu.tr/a", "ftp://www.bingol.edu.tr/x"));
        assertThrows(IOException.class, () -> NewsScraper.nextHop("https://www.bingol.edu.tr/a",
                "https://user@www.bingol.edu.tr/x"));
    }
}
