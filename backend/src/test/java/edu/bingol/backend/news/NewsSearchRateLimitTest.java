package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.news.dto.NewsPage;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.mock.web.MockHttpServletRequest;

/** P07-B1/K19: herkese acik haber aramasi IP basina 30/dk, en az 3 karakter, derin sayfa ust sinirli. */
class NewsSearchRateLimitTest {

    private final NewsRepository repo = mock(NewsRepository.class);
    private final NewsService service = new NewsService(repo);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final NewsController controller = new NewsController(service, mock(NewsSyncService.class), limiter,
            new ClientIp("10.0.0.0/8"));

    private static MockHttpServletRequest req(String ip) {
        MockHttpServletRequest r = new MockHttpServletRequest();
        r.setRemoteAddr(ip);
        return r;
    }

    @Test
    void searchIsRateLimitedPerIp() {
        when(repo.searchPage(any(), anyString(), anyString(), any(Pageable.class)))
                .thenReturn(new PageImpl<NewsSearchRow>(List.of(), PageRequest.of(0, 20), 0));
        controller.list(null, "yemek", 0, 20, req("203.0.113.9"));
        ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
        verify(limiter).check(key.capture(), eq(30), eq(Duration.ofMinutes(1)));
        assertEquals("newsq:ip:203.0.113.9", key.getValue());
    }

    @Test
    void rateLimitRejectionPreventsQuery() {
        doThrow(new RateLimitedException(30)).when(limiter).check(anyString(), anyInt(), any());
        assertThrows(RateLimitedException.class, () -> controller.list(null, "yemek", 0, 20, req("203.0.113.9")));
        verify(repo, never()).searchPage(any(), anyString(), anyString(), any(Pageable.class));
    }

    @Test
    void plainListingDoesNotConsumeSearchBudget() {
        when(repo.findByHiddenFalse(any(Pageable.class)))
                .thenReturn(new PageImpl<NewsRow>(List.of(), PageRequest.of(0, 20), 0));
        NewsPage p = controller.list(null, null, 0, 20, req("203.0.113.9"));
        assertEquals(0, p.totalItems());
        verify(limiter, never()).check(anyString(), anyInt(), any());
    }

    @Test
    void twoCharacterQueryIsRejected() {
        ApiException e = assertThrows(ApiException.class, () -> service.list(null, "ab", 0, 20));
        assertEquals(400, e.status().value());
        verify(repo, never()).searchPage(any(), anyString(), anyString(), any(Pageable.class));
    }

    @Test
    void deepPagesAreCapped() {
        when(repo.findByHiddenFalse(any(Pageable.class)))
                .thenReturn(new PageImpl<NewsRow>(List.of(), PageRequest.of(0, 20), 0));
        service.list(null, null, 100_000, 20);
        ArgumentCaptor<Pageable> cap = ArgumentCaptor.forClass(Pageable.class);
        verify(repo).findByHiddenFalse(cap.capture());
        assertEquals(NewsService.MAX_PAGE, cap.getValue().getPageNumber());
    }
}
