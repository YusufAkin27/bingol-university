package edu.bingol.backend.news;

import edu.bingol.backend.news.dto.NewsDetail;
import edu.bingol.backend.news.dto.NewsPage;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class NewsController {

    private final NewsService news;
    private final NewsSyncService sync;

    public NewsController(NewsService news, NewsSyncService sync) {
        this.news = news;
        this.sync = sync;
    }

    /** GET /api/news?type=HABER|DUYURU|ETKINLIK&q=metin&page=0&size=20 (type buyuk/kucuk harf fark etmez, bos ise hepsi; gecersiz type -> 400 NEWS_TYPE_INVALID; q opsiyonel, en az 2 karakter) */
    @GetMapping("/news")
    public NewsPage list(@RequestParam(required = false) String type,
                         @RequestParam(required = false) String q,
                         @RequestParam(defaultValue = "0") int page,
                         @RequestParam(defaultValue = "20") int size) {
        return news.list(NewsService.parseType(type), q, page, size);
    }

    @GetMapping("/news/{id}")
    public ResponseEntity<NewsDetail> get(@PathVariable Long id) {
        return ResponseEntity.of(news.find(id));
    }

    /** Manuel tetikleme (ADMIN). */
    @PostMapping("/admin/sync")
    public Map<ContentType, Integer> triggerSync() {
        return sync.sync();
    }
}
