package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

class NewsServiceSortTest {

    private final NewsRepository repo = mock(NewsRepository.class);
    private final NewsService service = new NewsService(repo);

    @Test
    void sortsNewestFirstWithNullDatesLastAndStableIdTiebreak() {
        when(repo.findByHiddenFalse(any(Pageable.class))).thenReturn(Page.empty());

        service.list(null, 0, 20);

        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(repo).findByHiddenFalse(captor.capture());
        Sort.Order date = captor.getValue().getSort().getOrderFor("publishedDate");
        assertEquals(Sort.Direction.DESC, date.getDirection());
        assertEquals(Sort.NullHandling.NULLS_LAST, date.getNullHandling());
        assertEquals(Sort.Direction.DESC, captor.getValue().getSort().getOrderFor("id").getDirection());
    }

    @Test
    void clampsPageAndSizeAndReportsTotals() {
        when(repo.findByHiddenFalse(any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 50), 120));

        var page = service.list(null, -3, 9999);

        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(repo).findByHiddenFalse(captor.capture());
        assertEquals(0, captor.getValue().getPageNumber());
        assertEquals(50, captor.getValue().getPageSize());
        assertEquals(3, page.totalPages());
        assertEquals(120, page.totalItems());
        assertTrue(page.items().isEmpty());
    }
}
