package edu.bingol.backend.bookmark;

import edu.bingol.backend.bookmark.dto.BookmarkItem;
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
    private final BookmarkFeedService feed;
    private final RateLimiter limiter;

    public BookmarkController(BookmarkService bookmarks, BookmarkFeedService feed, RateLimiter limiter) {
        this.bookmarks = bookmarks;
        this.feed = feed;
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

    /**
     * GET /api/bookmarks?cursor=&size=20 — type YOKSA eski davranis (yalniz haber, {@link BookmarkView}, cursor = kayit id'si).
     * type VARSA birlesik liste ({@link BookmarkItem}): ALL|NEWS|EVENT|COMMUNITY|POLL|ACADEMIC|POST|FORUM_TOPIC|FORUM_COMMENT,
     * yeni kaydedilen once, cursor = onceki yanittaki nextCursor (opak sayi). Gecersiz tur: 400 BOOKMARK_TYPE_INVALID.
     */
    @GetMapping
    public CursorPage<?> list(@RequestParam(required = false) String type,
                              @RequestParam(required = false) Long cursor,
                              @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        limiter.check("bookmark:read:" + uid, 120, Duration.ofMinutes(1)); // T-060
        if (type == null) {
            return bookmarks.list(uid, cursor, size);
        }
        return feed.list(uid, BookmarkFeedService.parseFilter(type), cursor, size);
    }

    /** PUT /api/bookmarks/{event|community|poll|academic|news}/{id}: idempotent kaydet (hedef gorunur degilse 404). */
    @PutMapping("/{type}/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void addTarget(@PathVariable String type, @PathVariable Long id) {
        BookmarkTarget target = BookmarkFeedService.parseTarget(type);
        Long uid = CurrentUser.id();
        limiter.check("bookmark:user:" + uid, 60, Duration.ofMinutes(1));
        feed.add(uid, target, id);
    }

    @DeleteMapping("/{type}/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeTarget(@PathVariable String type, @PathVariable Long id) {
        BookmarkTarget target = BookmarkFeedService.parseTarget(type);
        Long uid = CurrentUser.id();
        limiter.check("bookmark:user:" + uid, 60, Duration.ofMinutes(1));
        feed.remove(uid, target, id);
    }

    /** Liste ekranlarinda yildiz durumu icin bir turun kayitli kimlikleri (en fazla 1000). */
    @GetMapping("/{type}/ids")
    public NewsIds targetIds(@PathVariable String type) {
        BookmarkTarget target = BookmarkFeedService.parseTarget(type);
        Long uid = CurrentUser.id();
        limiter.check("bookmark:read:" + uid, 120, Duration.ofMinutes(1));
        return new NewsIds(feed.ids(uid, target));
    }

    /** Liste ekranlarinda yildiz durumunu isaretlemek icin kayitli haber id'leri (en fazla 1000). */
    @GetMapping("/news/ids")
    public NewsIds ids() {
        Long uid = CurrentUser.id();
        limiter.check("bookmark:read:" + uid, 120, Duration.ofMinutes(1)); // T-060
        return new NewsIds(bookmarks.newsIds(uid));
    }

    public record NewsIds(List<Long> ids) {}
}
