package edu.bingol.backend.news;

import edu.bingol.backend.news.dto.NewsDetail;
import edu.bingol.backend.news.dto.NewsPage;
import edu.bingol.backend.news.dto.NewsSummary;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Kayitli haber/duyuru/etkinlikleri sorgular. Kaynak siteye hic istek atmaz. */
@Service
@Transactional(readOnly = true)
public class NewsService {

    private static final int MAX_PAGE_SIZE = 50;

    private final NewsRepository repo;

    public NewsService(NewsRepository repo) {
        this.repo = repo;
    }

    /** type null ise tum turler; en yeni once. */
    public NewsPage list(ContentType type, int page, int size) {
        Pageable pageable = PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), MAX_PAGE_SIZE),
                Sort.by(Sort.Order.desc("publishedDate"), Sort.Order.desc("id")));
        Page<NewsItem> result = type == null ? repo.findAll(pageable) : repo.findByType(type, pageable);
        return new NewsPage(result.getContent().stream().map(NewsSummary::of).toList(),
                result.getNumber(), result.getTotalPages(), result.getTotalElements());
    }

    public Optional<NewsDetail> find(Long id) {
        return repo.findById(id).map(NewsDetail::of);
    }
}
