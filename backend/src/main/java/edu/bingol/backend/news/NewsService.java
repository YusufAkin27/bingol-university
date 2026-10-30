package edu.bingol.backend.news;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.news.dto.NewsDetail;
import edu.bingol.backend.news.dto.NewsPage;
import edu.bingol.backend.news.dto.NewsSummary;
import edu.bingol.backend.search.SearchQuery;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;

/** Kayitli haber/duyuru/etkinlikleri sorgular. Kaynak siteye hic istek atmaz. */
@Service
@Transactional(readOnly = true)
public class NewsService {

    private static final int MAX_PAGE_SIZE = 50;
    /** Onbellege yalniz ilk sayfalar girer (anahtar uzayi sinirli kalsin). */
    private static final int MAX_CACHED_PAGE = 20;
    private static final TypeReference<NewsPage> PAGE = new TypeReference<>() { };
    private static final TypeReference<NewsDetail> DETAIL = new TypeReference<>() { };

    private final NewsRepository repo;
    private CacheService cache = CacheService.passthrough();

    public NewsService(NewsRepository repo) {
        this.repo = repo;
    }

    /** Herkese ayni cevap (kullaniciya ozel alan yok): sunucu onbellegi `news` ad alani, senkron/gizleme yazmasinda gecersiz kilinir. */
    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.cache = cache;
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

    /**
     * q doluysa tam metin aramasi (basliga/ozete gore); bos/null ise mevcut davranis. Metinsiz ilk sayfalar
     * onbellekten gelir (arama metni kullanici girdisi oldugundan ASLA onbelleklenmez).
     */
    @Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
    public NewsPage list(ContentType type, String q, int page, int size) {
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        if ((q == null || q.isBlank()) && p <= MAX_CACHED_PAGE) {
            String key = "list:" + (type == null ? "all" : type.name()) + ":" + p + ":" + s;
            return cache.get("news", key, CacheTier.DAILY, PAGE, () -> load(type, q, p, s));
        }
        return load(type, q, p, s);
    }

    private NewsPage load(ContentType type, String q, int p, int s) {
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

    /** Bulunan kayit onbellekten gelir; "yok/gizli" sonucu onbelleklenmez (kimlik kullanici girdisi). */
    @Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
    public Optional<NewsDetail> find(Long id) {
        if (id == null) {
            return Optional.empty();
        }
        return Optional.ofNullable(cache.getPositive("news", "d:" + id, CacheTier.DAILY, DETAIL,
                () -> repo.findById(id).filter(n -> !n.isHidden()).map(NewsDetail::of).orElse(null)));
    }
}
