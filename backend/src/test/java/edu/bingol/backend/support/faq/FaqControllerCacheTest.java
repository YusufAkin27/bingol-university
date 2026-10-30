package edu.bingol.backend.support.faq;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.i18n.LocaleContextHolder;

/** SSS listesi: dil anahtarli sunucu onbellegi; yazmada (ad alani) yenilenir. */
class FaqControllerCacheTest {

    private final FaqRepository repo = mock(FaqRepository.class);
    private final CacheService cache = TestCaches.create();
    private final FaqController controller = new FaqController(repo);

    private static FaqItem item(String lang, String category, String q) {
        FaqItem f = new FaqItem();
        f.setLang(lang);
        f.setCategory(category);
        f.setQuestion(q);
        f.setAnswer("cevap");
        return f;
    }

    @BeforeEach
    void wire() {
        controller.setCache(cache);
        when(repo.findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc("tr"))
                .thenReturn(List.of(item("tr", "Genel", "Soru")));
        when(repo.findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc("en"))
                .thenReturn(List.of(item("en", "General", "Question")));
    }

    @AfterEach
    void reset() {
        LocaleContextHolder.resetLocaleContext();
    }

    @Test
    void cachedPerLanguageAndRefreshedOnInvalidate() {
        LocaleContextHolder.setLocale(Locale.forLanguageTag("tr"));
        assertEquals("Soru", controller.list().get(0).items().get(0).question());
        controller.list();
        LocaleContextHolder.setLocale(Locale.forLanguageTag("en"));
        assertEquals("Question", controller.list().get(0).items().get(0).question());
        verify(repo, times(1)).findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc("tr");
        verify(repo, times(1)).findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc("en");
        cache.invalidate("faq");
        controller.list();
        verify(repo, times(2)).findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc("en");
    }
}
