package edu.bingol.backend.search;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
        return new SearchResult(q, groups);
    }

    public record Group(SearchType type, List<SearchHit> items) {}

    public record SearchResult(String q, List<Group> groups) {}
}
