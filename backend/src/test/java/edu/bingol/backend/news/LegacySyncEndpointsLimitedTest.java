package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.menu.MenuController;
import edu.bingol.backend.menu.MenuService;
import edu.bingol.backend.menu.MenuSyncService;
import java.time.Duration;
import org.junit.jupiter.api.Test;

/**
 * P07-B12: eski POST /api/admin/sync ve /sync-menu uclari hiz sinirsizdi; artik panelin SourcesService.sync ucuyla ayni
 * sayaci paylasir (kaynak basina saatte 3), asilirsa kaynak siteye hic gidilmez.
 */
class LegacySyncEndpointsLimitedTest {

    private final RateLimiter limiter = mock(RateLimiter.class);
    private final NewsSyncService newsSync = mock(NewsSyncService.class);
    private final MenuSyncService menuSync = mock(MenuSyncService.class);
    private final NewsController news = new NewsController(mock(NewsService.class), newsSync, limiter,
            new ClientIp("10.0.0.0/8"));
    private final MenuController menu = new MenuController(mock(MenuService.class), menuSync, limiter);

    @Test
    void newsTriggerUsesSharedCounterAndStopsWhenExceeded() {
        news.triggerSync();
        verify(limiter).check(eq("sources-sync:NEWS"), eq(3), eq(Duration.ofHours(1)));
        verify(newsSync).sync();
    }

    @Test
    void newsTriggerDoesNotScrapeWhenRateLimited() {
        doThrow(new RateLimitedException(600)).when(limiter).check(anyString(), anyInt(), any());
        assertThrows(RateLimitedException.class, news::triggerSync);
        verify(newsSync, never()).sync();
    }

    @Test
    void menuTriggerUsesSharedCounterAndStopsWhenExceeded() {
        menu.triggerSync();
        verify(limiter).check(eq("sources-sync:MENU"), eq(3), eq(Duration.ofHours(1)));
        verify(menuSync).sync();

        doThrow(new RateLimitedException(600)).when(limiter).check(anyString(), anyInt(), any());
        assertThrows(RateLimitedException.class, menu::triggerSync);
        verify(menuSync, org.mockito.Mockito.times(1)).sync();
    }
}
