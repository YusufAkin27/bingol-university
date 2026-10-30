package edu.bingol.backend.common.cache;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import edu.bingol.backend.appinfo.AppSetting;
import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.support.faq.FaqItem;
import edu.bingol.backend.support.faq.FaqRepository;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Uctan uca (H2, tam baglam): varlik olaylari onbellegi gecersiz kilar (yonetici/senkron yazma yolu fark etmez),
 * gizlenen haber hemen kaybolur, HTTP onbellek basliklari beklenen uclarda.
 */
@SpringBootTest(properties = "app.cache.e2e=true")
class CacheEndToEndTest {

    @Autowired WebApplicationContext ctx;
    @Autowired CacheService cache;
    @Autowired NewsRepository news;
    @Autowired MenuRepository menu;
    @Autowired FaqRepository faq;
    @Autowired AppSettingRepository settings;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    MockMvc mvc;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        // Uretimdeki sira: guvenlik zinciri, sonra ETag filtresi (govdeyi tamponlar; Cache-Control commit oncesi yazilir)
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity())
                .addFilters(new org.springframework.web.filter.ShallowEtagHeaderFilter()).build();
    }

    private MockHttpServletResponse fetch(String uri, String lang) throws Exception {
        var b = get(uri);
        if (lang != null) {
            b = b.header("Accept-Language", lang);
        }
        return mvc.perform(b).andReturn().getResponse();
    }

    private static String body(MockHttpServletResponse r) throws Exception {
        return r.getContentAsString(StandardCharsets.UTF_8);
    }

    private NewsItem newsItem(String title) {
        NewsItem n = new NewsItem();
        n.setType(ContentType.HABER);
        n.setUrl("https://www.bingol.edu.tr/" + UUID.randomUUID());
        n.setTitle(title);
        n.setPublishedDate(LocalDate.of(2099, 1, 1)); // listenin basinda
        n.setFetchedAt(java.time.Instant.now());
        return news.save(n);
    }

    @Test
    void newsListSeesNewItemAfterSaveAndHiddenItemDisappears() throws Exception {
        String t1 = "E2E-haber-" + UUID.randomUUID();
        NewsItem a = newsItem(t1);
        MockHttpServletResponse r1 = fetch("/api/news?type=HABER&size=50", null);
        assertEquals(200, r1.getStatus());
        assertTrue(body(r1).contains(t1));
        assertEquals("public, max-age=60, stale-while-revalidate=120", r1.getHeader("Cache-Control"));

        String t2 = "E2E-haber-" + UUID.randomUUID();
        newsItem(t2); // senkron/yonetici yazmasi: varlik olayi onbellegi gecersiz kilar
        assertTrue(body(fetch("/api/news?type=HABER&size=50", null)).contains(t2),
                "yeni kayit gecersiz kilma sayesinde hemen gorunmeli");

        MockHttpServletResponse d1 = fetch("/api/news/" + a.getId(), null);
        assertEquals(200, d1.getStatus());
        assertTrue(body(d1).contains(t1));
        a.setHidden(true); // AdminNewsController.setHidden ile ayni yazma yolu
        news.save(a);
        assertEquals(404, fetch("/api/news/" + a.getId(), null).getStatus(), "gizlenen haber hemen 404 olmali");
        assertFalse(body(fetch("/api/news?type=HABER&size=50", null)).contains(t1));
    }

    @Test
    void notFoundResponsesCarryNoCacheHeaders() throws Exception {
        MockHttpServletResponse r = fetch("/api/news/999999999", null);
        assertEquals(404, r.getStatus());
        String cc = r.getHeader("Cache-Control");
        assertTrue(cc == null || !cc.startsWith("public"), "hata yanitlari public onbelleklenmemeli");
    }

    @Test
    void menuTodayReflectsUpdateAndHasHeaders() throws Exception {
        LocalDate today = LocalDate.now(ZoneId.of("Europe/Istanbul"));
        MenuDay day = menu.findByMenuDate(today).orElseGet(() -> {
            MenuDay m = new MenuDay();
            m.setMenuDate(today);
            m.setItems("A-yemek");
            return menu.save(m);
        });
        MockHttpServletResponse r1 = fetch("/api/menu/today", null);
        assertEquals(200, r1.getStatus());
        assertEquals("public, max-age=300, stale-while-revalidate=600", r1.getHeader("Cache-Control"));
        day.setItems("B-yemek-" + UUID.randomUUID());
        menu.save(day);
        assertTrue(body(fetch("/api/menu/today", null)).contains("B-yemek-"), "menu yazmasi hemen yansimali");
    }

    @Test
    void appInfoFollowsSettingWrites() throws Exception {
        AppSetting s = settings.findById("maintenance_mode").orElseGet(() -> {
            AppSetting n = new AppSetting();
            n.setKey("maintenance_mode");
            return n;
        });
        s.setValue("false");
        settings.save(s);
        assertTrue(body(fetch("/api/app/info", null)).contains("\"enabled\":false"));
        s.setValue("true");
        settings.save(s);
        assertTrue(body(fetch("/api/app/info", null)).contains("\"enabled\":true"), "bakim modu hemen yansimali");
        s.setValue("false");
        settings.save(s);
    }

    @Test
    void faqFollowsWritesAndKeepsLanguagesApart() throws Exception {
        String q = "E2E-soru-" + UUID.randomUUID();
        FaqItem f = new FaqItem();
        f.setLang("tr");
        f.setCategory("E2E");
        f.setQuestion(q);
        f.setAnswer("cevap");
        f = faq.save(f);
        assertTrue(body(fetch("/api/faq", "tr")).contains(q));
        assertFalse(body(fetch("/api/faq", "en")).contains(q + "-yok"));
        faq.delete(f);
        assertFalse(body(fetch("/api/faq", "tr")).contains(q), "silinen SSS hemen kaybolmali");
    }

    @Test
    void personalEndpointsAreNotCacheable() throws Exception {
        MockHttpServletResponse r = fetch("/api/legal/acceptance-status", null);
        assertTrue(r.getStatus() == 401 || r.getStatus() == 403);
        String cc = r.getHeader("Cache-Control");
        assertTrue(cc == null || !cc.contains("public"));
    }
}
