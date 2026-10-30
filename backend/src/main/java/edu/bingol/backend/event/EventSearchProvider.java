package edu.bingol.backend.event;

import edu.bingol.backend.community.Texts;
import edu.bingol.backend.search.SearchHit;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.search.SearchType;
import java.time.ZoneId;
import java.util.List;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Genel arama: yayindaki, bitmemis, herkese gorunur kullanici etkinlikleri (ILIKE, parametreli). */
@Component
public class EventSearchProvider implements SearchProvider {

    private final UserEventRepository events;

    public EventSearchProvider(UserEventRepository events) {
        this.events = events;
    }

    @Override
    public SearchType type() {
        return SearchType.EVENT;
    }

    @Override
    @Transactional(readOnly = true)
    public List<SearchHit> search(String q, int limit) {
        return events.search(Texts.likePattern(q), Math.max(1, limit)).stream()
                .map(e -> new SearchHit(SearchType.EVENT, e.getId(), e.getTitle(), snippet(e.getDescription()),
                        e.getCoverUrl(), e.getStartsAt().atZone(ZoneId.of("Europe/Istanbul")).toLocalDate().toString(),
                        null, null, null, null, e.getStartsAt().toString(),
                        e.getEndsAt() == null ? null : e.getEndsAt().toString()))
                .toList();
    }

    private static String snippet(String s) {
        if (s == null) {
            return null;
        }
        return s.length() <= 160 ? s : s.substring(0, 159) + "…";
    }
}
