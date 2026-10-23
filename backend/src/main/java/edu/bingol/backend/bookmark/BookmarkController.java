package edu.bingol.backend.bookmark;

import edu.bingol.backend.bookmark.dto.BookmarkView;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/bookmarks")
public class BookmarkController {

    private final BookmarkService bookmarks;
    private final RateLimiter limiter;

    public BookmarkController(BookmarkService bookmarks, RateLimiter limiter) {
        this.bookmarks = bookmarks;
        this.limiter = limiter;
    }

    @PutMapping("/news/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void add(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("bookmark:user:" + uid, 60, Duration.ofMinutes(1));
        bookmarks.addNews(uid, id);
    }

    @DeleteMapping("/news/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("bookmark:user:" + uid, 60, Duration.ofMinutes(1));
        bookmarks.removeNews(uid, id);
    }

    /** GET /api/bookmarks?cursor=&size=20 — yeni kaydedilen once; sonraki sayfa icin nextCursor'u cursor olarak gonderin. */
    @GetMapping
    public CursorPage<BookmarkView> list(@RequestParam(required = false) Long cursor,
                                         @RequestParam(defaultValue = "20") int size) {
        return bookmarks.list(CurrentUser.id(), cursor, size);
    }

    /** Liste ekranlarinda yildiz durumunu isaretlemek icin kayitli haber id'leri (en fazla 1000). */
    @GetMapping("/news/ids")
    public NewsIds ids() {
        return new NewsIds(bookmarks.newsIds(CurrentUser.id()));
    }

    public record NewsIds(List<Long> ids) {}
}
