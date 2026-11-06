package edu.bingol.backend.forum.search;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.category.ForumCategoryService;
import edu.bingol.backend.forum.search.ForumSearchRepository.Hit;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.forum.topic.spi.ForumTopicSummaries;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.search.SearchQuery;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Forum ici arama (konu basligi, aciklama, kategori adi, izin verilen yorum metni) + populer konular.
 * Gorunurluk iki katmanda: SQL (silinmis/kaldirilmis/pasif yazar/anonim yorum + engel/sessize alinan yazarlar) ve
 * {@link ForumTopicSummaries} (A'nin tek gorunurluk kurali; gorunmeyen sessizce atlanir). Sayfalama OFFSET imlecidir
 * (relevance siralamasi anahtar kumesine uygun degildir) ve {@value #MAX_OFFSET} satirla sinirlidir.
 */
@Service
public class ForumSearchService {

    static final int MAX_Q = 100;
    static final int MIN_Q = 2;
    static final int DEFAULT_SIZE = 15;
    static final int MAX_SIZE = 30;
    /** Aramada ulasilabilir en derin satir: sinirsiz OFFSET taramasi olmasin. */
    static final int MAX_OFFSET = 300;
    static final int POPULAR_SIZE = 10;

    private final ForumSearchRepository repo;
    private final ObjectProvider<ForumTopicSummaries> summaries;
    private final BlockService blocks;
    private final ObjectProvider<ForumMuteLookup> mutes;
    private final ForumCategoryService categories;

    public ForumSearchService(ForumSearchRepository repo, ObjectProvider<ForumTopicSummaries> summaries, BlockService blocks,
                              ObjectProvider<ForumMuteLookup> mutes, ForumCategoryService categories) {
        this.categories = categories;
        this.repo = repo;
        this.summaries = summaries;
        this.blocks = blocks;
        this.mutes = mutes;
    }

    public ForumPage<ForumSearchItem> search(Long viewerId, String rawQuery, Long categoryId, String sortRaw,
                                              String cursor, Integer sizeRaw) {
        String q = normalize(rawQuery);
        ForumSearchSort sort = ForumSearchSort.parse(sortRaw);
        int size = sizeRaw == null || sizeRaw <= 0 ? DEFAULT_SIZE : Math.min(sizeRaw, MAX_SIZE);
        int offset = decodeOffset(cursor);
        if (offset >= MAX_OFFSET) {
            return new ForumPage<>(List.of(), null);
        }
        List<Hit> hits = repo.search(q, categoryId, sort, excluded(viewerId), categories.matchingActiveIds(q),
                offset, size + 1);
        boolean more = hits.size() > size;
        List<Hit> page = more ? hits.subList(0, size) : hits;
        String next = more && offset + size < MAX_OFFSET ? encodeOffset(offset + size) : null;
        if (page.isEmpty()) {
            return new ForumPage<>(List.of(), null);
        }
        Map<Long, Hit> byId = new HashMap<>();
        page.forEach(h -> byId.put(h.topicId(), h));
        List<ForumSearchItem> items = new ArrayList<>();
        for (TopicSummary s : summaries.getObject().summaries(page.stream().map(Hit::topicId).toList(), viewerId)) {
            Hit h = byId.get(s.id());
            if (h != null) {
                items.add(new ForumSearchItem(s, h.matchedIn(), h.snippet()));
            }
        }
        return new ForumPage<>(items, next);
    }

    public List<TopicSummary> popular(Long viewerId) {
        List<Long> ids = repo.popular(excluded(viewerId), POPULAR_SIZE);
        return ids.isEmpty() ? List.of() : summaries.getObject().summaries(ids, viewerId);
    }

    /** Engel (iki yonlu) + sessize alinan yazarlar. */
    private Set<Long> excluded(Long viewerId) {
        Set<Long> out = new HashSet<>(blocks.hiddenFrom(viewerId));
        ForumMuteLookup m = mutes.getIfAvailable();
        if (m != null) {
            m.mutedBy(viewerId).forEach(id -> out.add(edu.bingol.backend.forum.topic.ForumViewerFilter.mutedKey(id)));
        }
        out.remove(viewerId);
        out.remove(edu.bingol.backend.forum.topic.ForumViewerFilter.mutedKey(viewerId));
        return out;
    }

    /** Bosluklari sadelestirir; 2'den kisaysa 400 FORUM_SEARCH_QUERY_TOO_SHORT; 100'den uzunsa keser. */
    static String normalize(String raw) {
        String q = raw == null ? "" : raw.trim().replaceAll("\\s+", " ");
        if (q.codePointCount(0, q.length()) < MIN_Q) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_SEARCH_QUERY_TOO_SHORT",
                    "Aramak için en az 2 karakter yazın.");
        }
        return q.codePointCount(0, q.length()) <= MAX_Q ? q : q.substring(0, q.offsetByCodePoints(0, MAX_Q));
    }

    static String encodeOffset(int offset) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(("o" + offset).getBytes(StandardCharsets.UTF_8));
    }

    /** Gecersiz/bozuk imlec = 0 (ilk sayfa); negatif/asiri deger kesilir. */
    static int decodeOffset(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return 0;
        }
        try {
            String s = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
            if (!s.startsWith("o")) {
                return 0;
            }
            int v = Integer.parseInt(s.substring(1));
            return Math.max(0, Math.min(v, MAX_OFFSET));
        } catch (IllegalArgumentException e) {
            return 0;
        }
    }

    /** ILIKE deseni (kacisli): %, _ ve ters bolu literal kalir. */
    static String likePattern(String q) {
        return SearchQuery.likePattern(q);
    }
}
