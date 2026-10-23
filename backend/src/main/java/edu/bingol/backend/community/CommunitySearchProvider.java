package edu.bingol.backend.community;

import edu.bingol.backend.search.SearchHit;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.search.SearchType;
import java.util.List;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Genel arama: yalnizca ACTIVE + PUBLIC topluluklar (ad/aciklama, ILIKE, parametreli). */
@Component
public class CommunitySearchProvider implements SearchProvider {

    private final CommunityRepository communities;

    public CommunitySearchProvider(CommunityRepository communities) {
        this.communities = communities;
    }

    @Override
    public SearchType type() {
        return SearchType.COMMUNITY;
    }

    @Override
    @Transactional(readOnly = true)
    public List<SearchHit> search(String q, int limit) {
        return communities.search(Texts.likePattern(q), Math.max(1, limit)).stream()
                .map(c -> new SearchHit(SearchType.COMMUNITY, c.getId(), c.getName(), snippet(c.getDescription()),
                        c.getCoverUrl(), null))
                .toList();
    }

    private static String snippet(String s) {
        if (s == null) {
            return null;
        }
        return s.length() <= 160 ? s : s.substring(0, 159) + "…";
    }
}
