package edu.bingol.backend.search;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.profile.ProfileService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import tools.jackson.core.type.TypeReference;

/**
 * Hafif onek onerisi (otomatik tamamlama). SUNUCUDA arama gecmisi TUTULMAZ ve sorgu metni log'a yazilmaz; "son
 * aramalar" yalniz istemcide durur. Kaynaklar: haber/duyuru/etkinlik basligi ve herkese acik kulup adi (herkese ayni
 * cevap: kisa omurlu sunucu onbellegi; anahtar sorgunun ozetidir, ham metin degil) ve kisi adi (goruntuleyene ozel:
 * engel/askiya alma suzgeci, onbelleklenmez). En fazla {@value #MAX_TOTAL} oneri.
 */
@Service
public class SearchSuggestService {

    private static final Logger log = LoggerFactory.getLogger(SearchSuggestService.class);
    public static final int MAX_TOTAL = 8;
    static final int NEWS_MAX = 4;
    static final int COMMUNITY_MAX = 2;
    static final int USER_MAX = 2;
    /** Kisi onerisi dizin taramasina yardim etmesin: en az 3 karakter. */
    static final int USER_MIN_LEN = 3;
    private static final TypeReference<List<Suggestion>> LIST = new TypeReference<>() { };

    public record Suggestion(String type, Long id, String text) {}

    public record SuggestResult(String q, List<Suggestion> suggestions) {}

    private final NamedParameterJdbcTemplate jdbc;
    private final CacheService cache;
    private final ProfileService profiles;

    public SearchSuggestService(NamedParameterJdbcTemplate jdbc, CacheService cache, ProfileService profiles) {
        this.jdbc = jdbc;
        this.cache = cache;
        this.profiles = profiles;
    }

    public SuggestResult suggest(Long viewerId, String rawQ) {
        String q = SearchQuery.normalize(rawQ);
        String like = prefixPattern(q);
        String key = "sg:" + digest(TrFold.fold(q));
        List<Suggestion> out = new ArrayList<>();
        out.addAll(safe(() -> cache.get("news", key, CacheTier.SHORT, LIST, () -> news(like))));
        out.addAll(safe(() -> cache.get("categories", key, CacheTier.SHORT, LIST, () -> communities(like))));
        if (viewerId != null && q.codePointCount(0, q.length()) >= USER_MIN_LEN) {
            out.addAll(safe(() -> users(viewerId, q)));
        }
        return new SuggestResult(q, out.size() <= MAX_TOTAL ? out : out.subList(0, MAX_TOTAL));
    }

    /** Bir kaynagin hatasi diger onerileri bozmaz. */
    private static List<Suggestion> safe(java.util.function.Supplier<List<Suggestion>> s) {
        try {
            List<Suggestion> r = s.get();
            return r == null ? List.of() : r;
        } catch (RuntimeException e) {
            log.warn("Oneri kaynagi basarisiz: {}", e.toString());
            return List.of();
        }
    }

    List<Suggestion> news(String like) {
        return jdbc.query("SELECT n.id, n.type, n.title FROM news_item n WHERE n.hidden = FALSE AND n.title ILIKE :p "
                        + "ESCAPE '\' ORDER BY n.published_date DESC NULLS LAST, n.id DESC LIMIT " + NEWS_MAX,
                Map.of("p", like),
                (rs, i) -> new Suggestion(newsType(rs.getString("type")), rs.getLong("id"), rs.getString("title")));
    }

    static String newsType(String contentType) {
        return switch (contentType == null ? "" : contentType) {
            case "DUYURU" -> SearchType.ANNOUNCEMENT.name();
            case "ETKINLIK" -> SearchType.EVENT_OFFICIAL.name();
            default -> SearchType.NEWS.name();
        };
    }

    List<Suggestion> communities(String like) {
        return jdbc.query("SELECT c.id, c.name FROM community c WHERE c.status = 'ACTIVE' AND c.visibility = 'PUBLIC' "
                        + "AND c.name ILIKE :p ESCAPE '\' ORDER BY c.name, c.id LIMIT " + COMMUNITY_MAX,
                Map.of("p", like),
                (rs, i) -> new Suggestion(SearchType.COMMUNITY.name(), rs.getLong("id"), rs.getString("name")));
    }

    private List<Suggestion> users(Long viewerId, String q) {
        return profiles.search(viewerId, q, USER_MAX, null).items().stream()
                .map(p -> new Suggestion(SearchType.USER.name(), p.id(), p.displayName())).toList();
    }

    /** Onek deseni (kacisli): "q%". */
    static String prefixPattern(String q) {
        String esc = q.replace("\\", "\\\\").replace("%", "\%").replace("_", "\_");
        return esc + "%";
    }

    static String digest(String s) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(h, 0, 16);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
