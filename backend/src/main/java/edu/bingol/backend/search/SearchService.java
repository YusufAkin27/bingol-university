package edu.bingol.backend.search;

import edu.bingol.backend.common.ApiException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Tum SearchProvider bean'lerini toplayip tur basina gruplanmis sonuc uretir. Arama kaydi tutulmaz (gizlilik);
 * sorgu metni log'a da yazilmaz.
 */
@Service
public class SearchService {

    private static final Logger log = LoggerFactory.getLogger(SearchService.class);
    public static final int DEFAULT_LIMIT = 5;
    public static final int MAX_LIMIT = 20;
    /** Tek tur modunda sayfa boyu ust siniri. */
    public static final int MAX_PAGE_LIMIT = 50;
    /** Derin offset taramasini (ve pahali OFFSET sorgularini) onlemek icin ust sinir. */
    public static final int MAX_OFFSET = 1000;

    private final List<SearchProvider> providers;

    public SearchService(List<SearchProvider> providers) {
        this.providers = providers;
    }

    /** Tur basina bos olmayan gruplar, SearchType sirasinda. type null ise tum turler. */
    public SearchResult search(String rawQ, SearchType type, Integer rawLimit) {
        String q = SearchQuery.normalize(rawQ);
        int limit = rawLimit == null ? DEFAULT_LIMIT : Math.min(Math.max(rawLimit, 1), MAX_LIMIT);
        List<Group> groups = new ArrayList<>();
        for (SearchProvider p : providers) {
            if (type != null && p.type() != type) {
                continue;
            }
            try {
                List<SearchHit> hits = p.search(q, limit);
                if (hits != null && !hits.isEmpty()) {
                    groups.add(new Group(p.type(), hits.size() <= limit ? hits : hits.subList(0, limit)));
                }
            } catch (Exception e) {
                // Bir turun hatasi tum aramayi bozmasin
                log.warn("Arama saglayicisi {} basarisiz: {}", p.type(), e.toString());
            }
        }
        groups.sort(Comparator.comparing(Group::type));
        return new SearchResult(q, groups, null);
    }

    /**
     * Tek tur icin sayfali arama. cursor = atlanacak sonuc sayisi (istemci icin opak; nextCursor ile devam).
     * Yanit gruplu bicimle aynidir: tek grup + nextCursor (baska sayfa yoksa null).
     */
    public SearchResult searchPage(String rawQ, SearchType type, Integer rawLimit, Long cursor) {
        String q = SearchQuery.normalize(rawQ);
        int limit = rawLimit == null ? DEFAULT_LIMIT : Math.min(Math.max(rawLimit, 1), MAX_PAGE_LIMIT);
        int offset = offset(cursor);
        List<Group> groups = new ArrayList<>();
        Long next = null;
        for (SearchProvider p : providers) {
            if (p.type() != type) {
                continue;
            }
            try {
                // limit+1: bir fazla kayit "devami var" bilgisini ucuza verir
                List<SearchHit> hits = p.search(q, limit + 1, offset);
                if (hits != null && !hits.isEmpty()) {
                    boolean more = hits.size() > limit && offset + limit <= MAX_OFFSET;
                    groups.add(new Group(type, hits.size() <= limit ? hits : hits.subList(0, limit)));
                    next = more ? (long) offset + limit : null;
                }
            } catch (Exception e) {
                log.warn("Arama saglayicisi {} basarisiz: {}", p.type(), e.toString());
            }
        }
        return new SearchResult(q, groups, next);
    }

    private static int offset(Long cursor) {
        if (cursor == null) {
            return 0;
        }
        if (cursor < 0 || cursor > MAX_OFFSET) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sayfa imleci.");
        }
        return cursor.intValue();
    }

    public record Group(SearchType type, List<SearchHit> items) {}

    /** nextCursor yalnizca tek tur (type) sayfalama modunda dolar; gruplu modda her zaman null. */
    public record SearchResult(String q, List<Group> groups, Long nextCursor) {}
}
