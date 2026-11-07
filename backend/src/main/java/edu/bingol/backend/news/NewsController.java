package edu.bingol.backend.news;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.news.dto.NewsDetail;
import edu.bingol.backend.news.dto.NewsPage;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
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
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public NewsController(NewsService news, NewsSyncService sync, RateLimiter limiter, ClientIp clientIp) {
        this.news = news;
        this.sync = sync;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    /** GET /api/news?type=HABER|DUYURU|ETKINLIK&q=metin&page=0&size=20 (type buyuk/kucuk harf fark etmez, bos ise hepsi; gecersiz type -> 400 NEWS_TYPE_INVALID; q opsiyonel, en az 3 karakter ve IP basina 30/dk; page en cok 200; cursor verilirse yanit CursorPage{items,nextCursor}, 0 = ilk sayfa) */
    @GetMapping("/news")
    public Object list(@RequestParam(required = false) String type,
                       @RequestParam(required = false) String q,
                       @RequestParam(defaultValue = "0") int page,
                       @RequestParam(defaultValue = "20") int size,
                       @RequestParam(required = false) Long cursor,
                       HttpServletRequest req) {
        // Kimliksiz uc: metin aramasi onbelleklenmez (kullanici girdisi), bu yuzden IP basina sinirlanir
        if (q != null && !q.isBlank()) {
            limiter.check("newsq:ip:" + clientIp.limitKey(req), 30, Duration.ofMinutes(1));
        }
        // cursor VERILIRSE imecli sozlesme (CursorPage; 0 = ilk sayfa), verilmezse eski NewsPage (docs/changes/news.md)
        if (cursor != null) {
            return news.listCursor(NewsService.parseType(type), q, cursor, size);
        }
        return news.list(NewsService.parseType(type), q, page, size);
    }

    @GetMapping("/news/{id}")
    public ResponseEntity<NewsDetail> get(@PathVariable Long id) {
        return ResponseEntity.of(news.find(id));
    }

    /**
     * Manuel tetikleme (ADMIN). Saatte 3 (panelin SourcesService.sync uciyla AYNI sayac: iki yoldan toplam 3);
     * asilirsa 429 + Retry-After. Yanit bicimi degismedi (sync senkron, 5 dk sure butceli).
     */
    @PostMapping("/admin/sync")
    public Map<ContentType, Integer> triggerSync() {
        limiter.check("sources-sync:NEWS", 3, Duration.ofHours(1));
        return sync.sync();
    }
}
