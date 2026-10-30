package edu.bingol.backend.community;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.search.SearchHit;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.search.SearchType;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Genel arama: yalnizca ACTIVE + PUBLIC topluluklar (ad/aciklama, ILIKE, parametreli). */
@Component
public class CommunitySearchProvider implements SearchProvider {

    private final CommunityRepository communities;
    private final CommunityMemberRepository members;

    public CommunitySearchProvider(CommunityRepository communities, CommunityMemberRepository members) {
        this.communities = communities;
        this.members = members;
    }

    @Override
    public SearchType type() {
        return SearchType.COMMUNITY;
    }

    @Override
    @Transactional(readOnly = true)
    public List<SearchHit> search(String q, int limit) {
        List<Community> found = communities.search(Texts.likePattern(q), Math.max(1, limit));
        if (found.isEmpty()) {
            return List.of();
        }
        // Uye sayilari ve benim uyeligim: tum sonuc listesi icin tek'er sorgu (N+1 yok)
        List<Long> ids = found.stream().map(Community::getId).toList();
        Map<Long, Long> counts = new HashMap<>();
        for (Object[] row : members.countByCommunity(ids, CommunityMember.Status.ACTIVE)) {
            counts.put((Long) row[0], (Long) row[1]);
        }
        Map<Long, String> mine = new HashMap<>();
        Long viewer = CurrentUser.idOrNull();
        if (viewer != null) {
            members.findByUserIdAndCommunityIdIn(viewer, ids).forEach(m ->
                    mine.put(m.getCommunityId(), m.getStatus() == CommunityMember.Status.BANNED ? "NONE" : m.getStatus().name()));
        }
        return found.stream()
                .map(c -> new SearchHit(SearchType.COMMUNITY, c.getId(), c.getName(), snippet(c.getDescription()),
                        c.getCoverUrl(), null, counts.getOrDefault(c.getId(), 0L), c.getCategory(),
                        mine.getOrDefault(c.getId(), "NONE"), null))
                .toList();
    }

    private static String snippet(String s) {
        if (s == null) {
            return null;
        }
        return s.length() <= 160 ? s : s.substring(0, 159) + "…";
    }
}
