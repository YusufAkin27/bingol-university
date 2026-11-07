package edu.bingol.backend.news;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.news.dto.NewsDetail;
import edu.bingol.backend.news.dto.NewsPage;
import edu.bingol.backend.news.dto.NewsSummary;
import edu.bingol.backend.search.SearchQuery;
import java.time.LocalDate;
import java.util.List;
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
    /** Sayfa numarasi ust siniri (derin OFFSET taramasi acik uc icin pahali); ustu bu sayfaya indirgenir. */
    public static final int MAX_PAGE = 200;
    /** Herkese acik haber aramasi alt siniri (K19): 2 karakter trigram indeksini kullanamaz. */
    public static final int SEARCH_MIN_LEN = 3;
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
        int p = Math.min(Math.max(page, 0), MAX_PAGE);
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        if ((q == null || q.isBlank()) && p <= MAX_CACHED_PAGE) {
            String key = "list:" + (type == null ? "all" : type.name()) + ":" + p + ":" + s;
            return cache.get("news", key, CacheTier.DAILY, PAGE, () -> load(type, q, p, s));
        }
        return load(type, q, p, s);
    }

    private static final TypeReference<CursorPage<NewsSummary>> CURSOR_PAGE = new TypeReference<>() { };
    private static final int ID_BITS = 40;
    private static final long ID_MASK = (1L << ID_BITS) - 1;

    /** Imec = (tarih gunu+1 | id): tarihsiz = 0; buyuk imec daha yeni demektir, siralama (tarih azalan, tarihsiz sonda, id azalan) ile birebir. */
    static long encodeCursor(LocalDate date, long id) {
        long day = date == null ? 0 : Math.max(date.toEpochDay(), 0) + 1;
        return (day << ID_BITS) | (id & ID_MASK);
    }

    /**
     * Imecli liste (B2). cursor <= 0 ilk sayfa. q yoksa imec yukaridaki bilesik anahtardir (sabit maliyet, OFFSET yok);
     * q varsa sonuc ts_rank/tarih sirali metin aramasidir ve imec bir SONRAKI SAYFA NUMARASIDIR (ayni size ile devam edin).
     * Yalniz ilk sayfa (q yok) onbellege girer; baska imeclerde anahtar uzayi sinirsiz olurdu.
     */
    @Transactional(propagation = Propagation.SUPPORTS, readOnly = true)
    public CursorPage<NewsSummary> listCursor(ContentType type, String q, long cursor, int size) {
        int s = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        long c = Math.max(cursor, 0);
        if (q != null && !q.isBlank()) {
            int p = (int) Math.min(c, MAX_PAGE);
            NewsPage page = load(type, q, p, s);
            Long next = p + 1 < page.totalPages() && p < MAX_PAGE ? (long) (p + 1) : null;
            return new CursorPage<>(page.items(), next);
        }
        if (c == 0) {
            String key = "cl:" + (type == null ? "all" : type.name()) + ":" + s;
            return cache.get("news", key, CacheTier.DAILY, CURSOR_PAGE, () -> loadCursor(type, 0, s));
        }
        return loadCursor(type, c, s);
    }

    private CursorPage<NewsSummary> loadCursor(ContentType type, long c, int s) {
        List<ContentType> types = type == null ? List.of(ContentType.values()) : List.of(type);
        Pageable pageable = PageRequest.of(0, s + 1);
        List<NewsRow> rows;
        if (c <= 0) {
            rows = repo.cursorDated(types, LocalDate.of(9999, 12, 31), 0L, pageable);
        } else {
            long day = c >>> ID_BITS;
            long id = c & ID_MASK;
            rows = day == 0 ? repo.cursorUndated(types, id, pageable)
                    : repo.cursorDated(types, LocalDate.ofEpochDay(day - 1), id, pageable);
        }
        return CursorPage.of(rows, s, r -> encodeCursor(r.getPublishedDate(), r.getId()), NewsSummary::of);
    }

    private NewsPage load(ContentType type, String q, int p, int s) {
        if (q != null && !q.isBlank()) {
            String nq = SearchQuery.normalize(q, SEARCH_MIN_LEN);
            Page<NewsSearchRow> result = repo.searchPage(type == null ? null : type.name(), nq,
                    SearchQuery.likePattern(nq), PageRequest.of(p, s));
            return new NewsPage(result.getContent().stream().map(NewsSummary::of).toList(),
                    result.getNumber(), result.getTotalPages(), result.getTotalElements());
        }
        Pageable pageable = PageRequest.of(p, s,
                Sort.by(Sort.Order.desc("publishedDate").nullsLast(), Sort.Order.desc("id")));
        Page<NewsRow> result = type == null ? repo.findByHiddenFalse(pageable)
                : repo.findByTypeAndHiddenFalse(type, pageable);
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
