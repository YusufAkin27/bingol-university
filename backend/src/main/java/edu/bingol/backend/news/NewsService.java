package edu.bingol.backend.news;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.news.dto.NewsDetail;
import edu.bingol.backend.news.dto.NewsPage;
import edu.bingol.backend.news.dto.NewsSummary;
import edu.bingol.backend.search.SearchQuery;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
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

    /** Metin turunu (buyuk/kucuk harf toleransli) cozer; bos ise null, taninmazsa 400 NEWS_TYPE_INVALID. */
    public static ContentType parseType(String raw) {
        try {
            return ContentType.parse(raw);
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "NEWS_TYPE_INVALID",
                    "Geçersiz tür. Geçerli değerler: DUYURU, HABER, ETKINLIK.");
        }
    }

    /** type null ise tum turler; en yeni once (tarihsizler sonda). */
    public NewsPage list(ContentType type, int page, int size) {
        return list(type, null, page, size);
    }

    /** q doluysa tam metin aramasi (basliga/ozete gore); bos/null ise mevcut davranis. */
    public NewsPage list(ContentType type, String q, int page, int size) {
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        Page<NewsItem> result;
        if (q != null && !q.isBlank()) {
            String nq = SearchQuery.normalize(q);
            result = repo.searchPage(type == null ? null : type.name(), nq, SearchQuery.likePattern(nq),
                    PageRequest.of(p, s));
        } else {
            Pageable pageable = PageRequest.of(p, s,
                    Sort.by(Sort.Order.desc("publishedDate").nullsLast(), Sort.Order.desc("id")));
            result = type == null ? repo.findByHiddenFalse(pageable) : repo.findByTypeAndHiddenFalse(type, pageable);
        }
        return new NewsPage(result.getContent().stream().map(NewsSummary::of).toList(),
                result.getNumber(), result.getTotalPages(), result.getTotalElements());
    }

    public Optional<NewsDetail> find(Long id) {
        return repo.findById(id).filter(n -> !n.isHidden()).map(NewsDetail::of);
    }
}
