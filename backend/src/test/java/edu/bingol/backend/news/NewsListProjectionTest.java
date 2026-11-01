package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Method;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import org.hibernate.resource.jdbc.spi.StatementInspector;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.Query;

/**
 * P07-B1: haber liste/favori/arama sorgulari TEXT `content` sutununu SELECT'e koymaz (liste ucu 20-50 satir x 8-20 KB
 * gereksiz TOAST okumasi yapmasin). JPQL yollari H2 uzerinde gercek SQL ile, native arama (PostgreSQL'e ozel) SQL metniyle denetlenir.
 */
@SpringBootTest(properties = "spring.jpa.properties.hibernate.session_factory.statement_inspector="
        + "edu.bingol.backend.news.NewsListProjectionTest$Capture")
class NewsListProjectionTest {

    public static class Capture implements StatementInspector {
        static final List<String> SQL = new CopyOnWriteArrayList<>();

        @Override
        public String inspect(String sql) {
            SQL.add(sql);
            return sql;
        }
    }

    @Autowired NewsRepository repo;

    private NewsItem seed(String url, ContentType type, boolean hidden) {
        NewsItem n = new NewsItem();
        n.setType(type);
        n.setUrl(url);
        n.setTitle("Baslik " + url);
        n.setSummary("ozet");
        n.setContent("UZUN-ICERIK");
        n.setPublishedDate(LocalDate.of(2026, 10, 1));
        n.setEventDate(LocalDate.of(2026, 11, 5));
        n.setHidden(hidden);
        n.setFetchedAt(Instant.now());
        return repo.save(n);
    }

    @BeforeEach
    void clean() {
        repo.deleteAll();
        Capture.SQL.clear();
    }

    @Test
    void listQueriesDoNotSelectContent() {
        seed("https://t/p07-1", ContentType.HABER, false);
        seed("https://t/p07-2", ContentType.DUYURU, false);
        seed("https://t/p07-3", ContentType.HABER, true);
        Capture.SQL.clear();

        var all = repo.findByHiddenFalse(PageRequest.of(0, 20, Sort.by(Sort.Order.desc("publishedDate").nullsLast(),
                Sort.Order.desc("id"))));
        assertEquals(2, all.getTotalElements());
        assertFalse(lastNewsSelectBefore("count").contains("content"), lastNewsSelectBefore("count"));
        assertEquals(LocalDate.of(2026, 11, 5), all.getContent().get(0).getEventDate());

        Capture.SQL.clear();
        var typed = repo.findByTypeAndHiddenFalse(ContentType.HABER, PageRequest.of(0, 20));
        assertEquals(1, typed.getTotalElements());
        assertFalse(lastNewsSelectBefore("count").contains("content"));
        assertEquals(ContentType.HABER, typed.getContent().get(0).getType());
    }

    private static String lastNewsSelectBefore(String notContaining) {
        return Capture.SQL.stream().filter(s -> s.toLowerCase().contains("from news_item")
                && !s.toLowerCase().contains(notContaining)).reduce((a, b) -> b).orElseThrow();
    }

    @Test
    void bookmarkLookupDoesNotSelectContentAndSkipsHidden() {
        NewsItem a = seed("https://t/p07-4", ContentType.HABER, false);
        NewsItem hidden = seed("https://t/p07-5", ContentType.HABER, true);
        Capture.SQL.clear();

        var rows = repo.findByIdInAndHiddenFalse(List.of(a.getId(), hidden.getId()));
        assertEquals(1, rows.size());
        assertEquals(a.getId(), rows.get(0).getId());
        assertFalse(lastNewsSelectBefore("zzz").contains("content"), lastNewsSelectBefore("zzz"));
    }

    @Test
    void nativeSearchQueriesNeverSelectStar() throws Exception {
        for (Method m : NewsRepository.class.getDeclaredMethods()) {
            Query q = m.getAnnotation(Query.class);
            if (q != null && q.nativeQuery()) {
                assertFalse(q.value().contains("n.*"), m.getName() + " tum sutunlari cekiyor");
                assertFalse(q.value().toLowerCase().contains("n.content"), m.getName());
            }
        }
        Method m = NewsRepository.class.getMethod("searchPage", String.class, String.class, String.class,
                org.springframework.data.domain.Pageable.class);
        assertTrue(m.getAnnotation(Query.class).value().contains("n.title AS title"));
    }
}
