package edu.bingol.backend.forum.search;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.search.SearchHit;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.search.SearchType;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Genel arama: forum konusu turu. Gorunurluk {@link ForumSearchService}'e aittir (silinmis/kaldirilmis konu yok,
 * engel + sessize alinan yazar elenir, anonim konularda yazar bilgisi yoktur). Sonuca YAZAR hic konmaz (anonim
 * konuda sizinti riski sifir): baslik, ozet, kategori ve tarih.
 */
@Component
public class ForumSearchProvider implements SearchProvider {

    private final ForumSearchService forum;

    public ForumSearchProvider(ForumSearchService forum) {
        this.forum = forum;
    }

    @Override
    public SearchType type() {
        return SearchType.FORUM_TOPIC;
    }

    @Override
    public List<SearchHit> search(String q, int limit) {
        return search(q, limit, 0);
    }

    @Override
    public List<SearchHit> search(String q, int limit, int offset) {
        Long viewer = CurrentUser.idOrNull();
        if (viewer == null) {
            return List.of();
        }
        // ForumSearchService sayfa boyunu 30 ile, offset'i 300 ile sinirlar
        String cursor = offset <= 0 ? null : ForumSearchService.encodeOffset(offset);
        return forum.search(viewer, q, null, null, cursor, limit).items().stream()
                .map(i -> hit(i.topic(), i.snippet())).toList();
    }

    static SearchHit hit(TopicSummary t, String snippet) {
        String text = snippet != null ? snippet : t.bodyPreview();
        return new SearchHit(SearchType.FORUM_TOPIC, t.id(), t.title(), text, t.thumbnail() == null ? null : t.thumbnail().thumbUrl(),
                t.createdAt() == null ? null : t.createdAt().toString(), null,
                t.category() == null ? null : t.category().name(), null, (long) t.likeCount());
    }
}
