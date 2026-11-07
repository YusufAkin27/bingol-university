package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.news.dto.NewsSummary;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;

class NewsCursorTest {

    private final NewsRepository repo = mock(NewsRepository.class);
    private final NewsService service = new NewsService(repo);

    private static NewsRow row(long id, LocalDate d) {
        NewsRow r = mock(NewsRow.class);
        when(r.getId()).thenReturn(id);
        when(r.getType()).thenReturn(ContentType.HABER);
        when(r.getTitle()).thenReturn("b" + id);
        when(r.getPublishedDate()).thenReturn(d);
        return r;
    }

    @Test
    void cursorOrderMatchesListOrder() {
        LocalDate d1 = LocalDate.of(2026, 5, 1);
        LocalDate d2 = LocalDate.of(2026, 4, 1);
        // siralama: (d1,9) > (d1,3) > (d2,50) > (tarihsiz,70) > (tarihsiz,2)
        List<Long> keys = List.of(NewsService.encodeCursor(d1, 9), NewsService.encodeCursor(d1, 3),
                NewsService.encodeCursor(d2, 50), NewsService.encodeCursor(null, 70), NewsService.encodeCursor(null, 2));
        for (int i = 0; i + 1 < keys.size(); i++) {
            assertTrue(keys.get(i) > keys.get(i + 1), "i=" + i);
        }
    }

    @Test
    void firstPageUsesSentinelAndReturnsNextCursor() {
        LocalDate d = LocalDate.of(2026, 5, 1);
        when(repo.cursorDated(any(), any(), anyLong(), any(Pageable.class)))
                .thenReturn(new ArrayList<>(List.of(row(9, d), row(8, d), row(7, d))));

        CursorPage<NewsSummary> p = service.listCursor(null, null, 0, 2);

        assertEquals(2, p.items().size());
        assertEquals(NewsService.encodeCursor(d, 8), p.nextCursor());
        verify(repo).cursorDated(any(), eq(LocalDate.of(9999, 12, 31)), eq(0L), any(Pageable.class));
    }

    @Test
    void dateCursorDecodesToDateAndId() {
        LocalDate d = LocalDate.of(2026, 5, 1);
        when(repo.cursorDated(any(), any(), anyLong(), any(Pageable.class))).thenReturn(List.of(row(7, d)));

        CursorPage<NewsSummary> p = service.listCursor(ContentType.HABER, null, NewsService.encodeCursor(d, 8), 5);

        assertNull(p.nextCursor());
        verify(repo).cursorDated(eq(List.of(ContentType.HABER)), eq(d), eq(8L), any(Pageable.class));
    }

    @Test
    void undatedCursorUsesUndatedQuery() {
        when(repo.cursorUndated(any(), anyLong(), any(Pageable.class))).thenReturn(List.of());

        CursorPage<NewsSummary> p = service.listCursor(null, null, NewsService.encodeCursor(null, 70), 5);

        assertTrue(p.items().isEmpty());
        verify(repo).cursorUndated(any(), eq(70L), any(Pageable.class));
    }
}
