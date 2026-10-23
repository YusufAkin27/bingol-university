package edu.bingol.backend.bookmark;

import edu.bingol.backend.bookmark.dto.BookmarkView;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.news.dto.NewsSummary;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BookmarkService {

    /** Kullanici basina en fazla kayit; ids ucu da bu sinirla tam liste doner. */
    public static final int MAX_PER_USER = 1000;

    private final BookmarkRepository repo;
    private final NewsRepository news;

    public BookmarkService(BookmarkRepository repo, NewsRepository news) {
        this.repo = repo;
        this.news = news;
    }

    /** Idempotent: zaten kayitliysa sessizce basarili. Limit yalnizca yeni kayitta kontrol edilir. */
    @Transactional
    public void addNews(Long uid, Long newsId) {
        if (!news.existsById(newsId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Haber bulunamadı.");
        }
        if (repo.existsByUserIdAndTargetTypeAndTargetId(uid, BookmarkTarget.NEWS, newsId)) {
            return;
        }
        if (repo.countByUserId(uid) >= MAX_PER_USER) {
            throw new ApiException(HttpStatus.CONFLICT, "BOOKMARK_LIMIT",
                    "En fazla " + MAX_PER_USER + " kayıt tutulabilir. Önce bazılarını kaldırın.");
        }
        repo.insertIfAbsent(uid, BookmarkTarget.NEWS.name(), newsId);
    }

    /** Idempotent: kayit yoksa da basarili. */
    @Transactional
    public void removeNews(Long uid, Long newsId) {
        repo.remove(uid, BookmarkTarget.NEWS, newsId);
    }

    @Transactional(readOnly = true)
    public CursorPage<BookmarkView> list(Long uid, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<Bookmark> rows = repo.page(uid, BookmarkTarget.NEWS, cursor == null ? Long.MAX_VALUE : cursor, PageRequest.of(0, s + 1));
        CursorPage<Bookmark> page = CursorPage.of(rows, s, Bookmark::getId, Function.identity());
        Map<Long, NewsItem> items = news.findAllById(page.items().stream().map(Bookmark::getTargetId).toList())
                .stream().collect(Collectors.toMap(NewsItem::getId, Function.identity()));
        // Kaynagi silinmis haber (olmamali) listeden dusulur
        List<BookmarkView> views = page.items().stream()
                .filter(b -> items.containsKey(b.getTargetId()))
                .map(b -> new BookmarkView(b.getTargetType(), b.getTargetId(), b.getCreatedAt(),
                        NewsSummary.of(items.get(b.getTargetId()))))
                .toList();
        return new CursorPage<>(views, page.nextCursor());
    }

    @Transactional(readOnly = true)
    public List<Long> newsIds(Long uid) {
        return repo.targetIds(uid, BookmarkTarget.NEWS, PageRequest.of(0, MAX_PER_USER));
    }
}
