package edu.bingol.backend.bookmark;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.bookmark.dto.BookmarkView;
import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class BookmarkServiceTest {

    private final BookmarkRepository repo = mock(BookmarkRepository.class);
    private final NewsRepository news = mock(NewsRepository.class);
    private final BookmarkService service = new BookmarkService(repo, news);

    @Test
    void unknownNewsIs404() {
        when(news.existsByIdAndHiddenFalse(5L)).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> service.addNews(1L, 5L));

        assertEquals(404, e.status().value());
        verify(repo, never()).insertIfAbsent(anyLong(), anyString(), anyLong());
    }

    @Test
    void addIsIdempotentWhenAlreadyBookmarked() {
        when(news.existsByIdAndHiddenFalse(5L)).thenReturn(true);
        when(repo.existsByUserIdAndTargetTypeAndTargetId(1L, BookmarkTarget.NEWS, 5L)).thenReturn(true);
        // Limit dolu olsa bile mevcut kaydi tekrar PUT etmek basarili olmali
        when(repo.countByUserId(1L)).thenReturn((long) BookmarkService.MAX_PER_USER);

        service.addNews(1L, 5L);

        verify(repo, never()).insertIfAbsent(anyLong(), anyString(), anyLong());
    }

    @Test
    void addInsertsNewBookmark() {
        when(news.existsByIdAndHiddenFalse(5L)).thenReturn(true);
        when(repo.countByUserId(1L)).thenReturn(10L);

        service.addNews(1L, 5L);

        verify(repo).insertIfAbsent(1L, "NEWS", 5L);
    }

    @Test
    void addRejectsWhenLimitReached() {
        when(news.existsByIdAndHiddenFalse(5L)).thenReturn(true);
        when(repo.countByUserId(1L)).thenReturn((long) BookmarkService.MAX_PER_USER);

        ApiException e = assertThrows(ApiException.class, () -> service.addNews(1L, 5L));

        assertEquals("BOOKMARK_LIMIT", e.code());
        verify(repo, never()).insertIfAbsent(anyLong(), anyString(), anyLong());
    }

    @Test
    void removeIsIdempotent() {
        when(repo.remove(1L, BookmarkTarget.NEWS, 5L)).thenReturn(0);

        service.removeNews(1L, 5L);

        verify(repo).remove(1L, BookmarkTarget.NEWS, 5L);
    }

    @Test
    void listPagesWithCursorAndSkipsMissingNews() {
        // size 2 istendi -> 3 satir geldi: sonraki sayfa var, imec son gosterilen kaydin id'si
        when(repo.page(anyLong(), any(), anyLong(), any())).thenReturn(List.of(bm(30, 3), bm(20, 2), bm(10, 1)));
        when(news.findAllById(any())).thenReturn(List.of(item(3L)));

        CursorPage<BookmarkView> page = service.list(1L, null, 2);

        assertEquals(20L, page.nextCursor());
        assertEquals(1, page.items().size());
        assertEquals(3L, page.items().get(0).targetId());
    }

    private static Bookmark bm(long id, long newsId) {
        Bookmark b = new Bookmark();
        b.setId(id);
        b.setUserId(1L);
        b.setTargetType(BookmarkTarget.NEWS);
        b.setTargetId(newsId);
        b.setCreatedAt(Instant.now());
        return b;
    }

    private static NewsItem item(long id) {
        NewsItem n = new NewsItem();
        n.setId(id);
        n.setType(ContentType.HABER);
        n.setTitle("Baslik");
        n.setUrl("https://x/" + id);
        return n;
    }
}
