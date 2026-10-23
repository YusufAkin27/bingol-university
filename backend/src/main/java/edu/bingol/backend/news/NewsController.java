package edu.bingol.backend.news;

import java.util.List;
import java.util.Map;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
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

    public record NewsSummary(Long id, ContentType type, String title, String summary,
                              String imageUrl, String publishedDate, String url) {
        static NewsSummary of(NewsItem n) {
            return new NewsSummary(n.getId(), n.getType(), n.getTitle(), n.getSummary(), n.getImageUrl(),
                    n.getPublishedDate() == null ? null : n.getPublishedDate().toString(), n.getUrl());
        }
    }

    public record NewsDetail(Long id, ContentType type, String title, String content,
                             String imageUrl, String publishedDate, String url) {
        static NewsDetail of(NewsItem n) {
            return new NewsDetail(n.getId(), n.getType(), n.getTitle(), n.getContent(), n.getImageUrl(),
                    n.getPublishedDate() == null ? null : n.getPublishedDate().toString(), n.getUrl());
        }
    }

    public record PageResponse(List<NewsSummary> items, int page, int totalPages, long totalItems) {}

    private final NewsRepository repo;
    private final NewsSyncService sync;

    public NewsController(NewsRepository repo, NewsSyncService sync) {
        this.repo = repo;
        this.sync = sync;
    }

    /** GET /api/news?type=HABER|DUYURU|ETKINLIK&page=0&size=20 (type bos ise hepsi) */
    @GetMapping("/news")
    public PageResponse list(@RequestParam(required = false) ContentType type,
                             @RequestParam(defaultValue = "0") int page,
                             @RequestParam(defaultValue = "20") int size) {
        var pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 50),
                Sort.by(Sort.Order.desc("publishedDate"), Sort.Order.desc("id")));
        Page<NewsItem> p = type == null ? repo.findAll(pageable) : repo.findByType(type, pageable);
        return new PageResponse(p.getContent().stream().map(NewsSummary::of).toList(),
                p.getNumber(), p.getTotalPages(), p.getTotalElements());
    }

    @GetMapping("/news/{id}")
    public ResponseEntity<NewsDetail> get(@PathVariable Long id) {
        return repo.findById(id).map(n -> ResponseEntity.ok(NewsDetail.of(n)))
                .orElse(ResponseEntity.notFound().build());
    }

    /** Manuel tetikleme (kimlik dogrulama gerekir). */
    @PostMapping("/admin/sync")
    public Map<ContentType, Integer> triggerSync() {
        return sync.sync();
    }
}
