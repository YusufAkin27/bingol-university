package edu.bingol.backend.search;

import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsRepository;
import java.util.List;

/**
 * news_item uzerinde tek bir icerik turu (HABER/DUYURU/ETKINLIK) icin arama. Uc ornegi NewsSearchConfig olusturur.
 * Sorgu PostgreSQL'e ozeldir (tsvector + ILIKE yedegi); parametreli oldugu icin enjeksiyon yoktur.
 */
public class NewsSearchProvider implements SearchProvider {

    private static final int SNIPPET_LEN = 160;

    private final NewsRepository repo;
    private final SearchType type;
    private final ContentType contentType;

    public NewsSearchProvider(NewsRepository repo, SearchType type, ContentType contentType) {
        this.repo = repo;
        this.type = type;
        this.contentType = contentType;
    }

    @Override
    public SearchType type() {
        return type;
    }

    @Override
    public List<SearchHit> search(String q, int limit) {
        return search(q, limit, 0);
    }

    @Override
    public List<SearchHit> search(String q, int limit, int offset) {
        return repo.searchHits(contentType.name(), q, SearchQuery.likePattern(q), limit, offset).stream()
                .map(r -> new SearchHit(type, r.getId(), r.getTitle(), snippet(r.getSummary()),
                        r.getImageUrl(), r.getPublishedDate()))
                .toList();
    }

    private static String snippet(String summary) {
        if (summary == null || summary.isBlank()) {
            return null;
        }
        String flat = summary.replaceAll("\\s+", " ").trim();
        return flat.length() <= SNIPPET_LEN ? flat : flat.substring(0, SNIPPET_LEN).trim() + "…";
    }
}
