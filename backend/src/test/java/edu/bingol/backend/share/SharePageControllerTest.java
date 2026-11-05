package edu.bingol.backend.share;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.media.PostMediaService;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver;

/** Herkese acik paylasim sayfasi: OG etiketleri, gizlilik (notr sayfa), XSS kacisi, dil, onbellek, hiz siniri. */
class SharePageControllerTest {

    private final ShareService shares = mock(ShareService.class);
    private final PostMediaService postMedia = mock(PostMediaService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ClientIp clientIp = mock(ClientIp.class);
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/share");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        SharePageController c = new SharePageController(shares, postMedia, limiter, clientIp, new SharePageRenderer(ms));
        ReflectionTestUtils.setField(c, "iosStoreUrl", "https://apps.apple.com/tr/app/id6830530499");
        ReflectionTestUtils.setField(c, "androidStoreUrl", "https://play.google.com/store/apps/details?id=tr.com.bukampus.app");
        ReflectionTestUtils.setField(c, "appleAppId", "6830530499");
        ReflectionTestUtils.setField(c, "androidPackage", "tr.com.bukampus.app");
        ReflectionTestUtils.setField(c, "perMinute", 300);
        when(shares.baseUrl()).thenReturn("https://bukampus.com.tr");
        when(clientIp.limitKey(any(jakarta.servlet.http.HttpServletRequest.class))).thenReturn("1.2.3.4");
        AcceptHeaderLocaleResolver lr = new AcceptHeaderLocaleResolver();
        lr.setDefaultLocale(java.util.Locale.forLanguageTag("tr"));
        mvc = MockMvcBuilders.standaloneSetup(c).setLocaleResolver(lr).build();
    }

    private static ShareService.Resolved news(String title, String desc, String image) {
        return new ShareService.Resolved(new ShareRef(ShareType.NEWS, 12), null, title, "Bingöl Üniversitesi", desc,
                image, null, "HABER", Instant.parse("2026-11-01T00:00:00Z"), null);
    }

    private MockHttpServletResponse call(String path, String lang) throws Exception {
        var rq = get(path);
        if (lang != null) {
            rq.header("Accept-Language", lang);
        }
        return mvc.perform(rq).andReturn().getResponse();
    }

    private static String body(MockHttpServletResponse r) throws Exception {
        return r.getContentAsString(StandardCharsets.UTF_8);
    }

    @Test
    void publicNewsRendersOpenGraphTwitterAndSmartBanner() throws Exception {
        when(shares.publicView(new ShareRef(ShareType.NEWS, 12))).thenReturn(Optional.of(
                news("Final takvimi aciklandı", "Sinav tarihleri yayinda", "https://www.bingol.edu.tr/media/1/a.jpg")));

        MockHttpServletResponse r = call("/s/n/12", "tr");
        String h = body(r);

        assertEquals(200, r.getStatus());
        assertTrue(r.getContentType().startsWith("text/html"));
        assertTrue(h.contains("<meta property=\"og:title\" content=\"Final takvimi aciklandı\">"));
        assertTrue(h.contains("<meta property=\"og:description\" content=\"Sinav tarihleri yayinda\">"));
        assertTrue(h.contains("<meta property=\"og:image\" content=\"https://www.bingol.edu.tr/media/1/a.jpg\">"));
        assertTrue(h.contains("<meta property=\"og:url\" content=\"https://bukampus.com.tr/s/n/12\">"));
        assertTrue(h.contains("<meta property=\"og:site_name\" content=\"BÜ Kampüs\">"));
        assertTrue(h.contains("<meta property=\"og:type\" content=\"article\">"));
        assertTrue(h.contains("<meta name=\"twitter:card\" content=\"summary_large_image\">"));
        assertTrue(h.contains("<meta name=\"apple-itunes-app\" content=\"app-id=6830530499, app-argument=https://bukampus.com.tr/s/n/12\">"));
        assertTrue(h.contains("href=\"bukampus://s/n/12\""));
        assertTrue(h.contains("https://apps.apple.com/tr/app/id6830530499"));
        assertTrue(h.contains("https://play.google.com/store/apps/details?id=tr.com.bukampus.app"));
        assertTrue(h.contains("intent://s/n/12#Intent;scheme=bukampus;package=tr.com.bukampus.app;S.browser_fallback_url="));
        assertTrue(h.contains("https://bukampus.com.tr/tr/download"));
        assertTrue(h.contains("<meta name=\"robots\" content=\"noindex,nofollow\">"));
        assertEquals("noindex, nofollow", r.getHeader("X-Robots-Tag"));
        assertEquals("public, max-age=300", r.getHeader("Cache-Control"));
        assertEquals("Accept-Language", r.getHeader("Vary"));
    }

    @Test
    void cspAuthorisesOnlyTheInlineScriptAndStyleByHashAndNoExternalScripts() throws Exception {
        when(shares.publicView(any())).thenReturn(Optional.of(news("T", "D", null)));

        MockHttpServletResponse r = call("/s/n/12", null);
        String csp = r.getHeader("Content-Security-Policy");
        String h = body(r);

        assertTrue(csp.contains("default-src 'none'"));
        assertTrue(csp.contains("script-src 'sha256-" + SharePageRenderer.sha256(SharePageRenderer.SCRIPT) + "'"));
        assertTrue(csp.contains("style-src 'sha256-" + SharePageRenderer.sha256(SharePageRenderer.CSS) + "'"));
        assertTrue(csp.contains("frame-ancestors 'none'"));
        assertFalse(csp.contains("unsafe-inline"));
        // tek satir ici betik, harici betik yok, satir ici stil niteligi yok
        Matcher m = Pattern.compile("<script").matcher(h);
        int scripts = 0;
        while (m.find()) {
            scripts++;
        }
        assertEquals(1, scripts);
        assertFalse(h.contains("<script src"));
        assertFalse(h.contains(" style=\""));
        assertTrue(h.contains("<script>" + SharePageRenderer.SCRIPT + "</script>"));
        assertTrue(h.contains("<style>" + SharePageRenderer.CSS + "</style>"));
        assertTrue(h.contains("location.replace(s)"));
        assertTrue(h.contains("1500"));
    }

    @Test
    void unknownHiddenAndMalformedAllGetTheSameNeutralPage() throws Exception {
        when(shares.publicView(any())).thenReturn(Optional.empty());

        String missing = body(call("/s/p/999", "tr"));
        String hiddenLooksSame = body(call("/s/p/5", "tr"));
        MockHttpServletResponse badType = call("/s/x/5", "tr");
        MockHttpServletResponse badId = call("/s/p/abc", "tr");

        for (MockHttpServletResponse r : new MockHttpServletResponse[] {badType, badId}) {
            assertEquals(200, r.getStatus());
            assertTrue(body(r).contains("BÜ Kampüs’te bir içerik"));
            assertEquals("noindex, nofollow", r.getHeader("X-Robots-Tag"));
        }
        assertTrue(missing.contains("<meta property=\"og:title\" content=\"BÜ Kampüs’te bir içerik\">"));
        assertTrue(missing.contains("og:image\" content=\"https://bukampus.com.tr/og.png\""));
        assertTrue(missing.contains("href=\"bukampus://s/p/999\""));
        // var/yok ayrimi yok: yalniz kimlik/baglanti farki, baslik ve aciklama ayni
        assertEquals(strip(missing), strip(hiddenLooksSame));
        verify(shares, never()).publicView(new ShareRef(ShareType.POST, 0));
    }

    private static String strip(String h) {
        return h.replaceAll("/s/p/\\d+", "/s/p/N");
    }

    @Test
    void userTextIsHtmlEscapedEverywhere() throws Exception {
        String evil = "<script>alert(1)</script>\"><img src=x onerror=alert(2)> & 'x'";
        when(shares.publicView(any())).thenReturn(Optional.of(news(evil, evil, null)));

        String h = body(call("/s/n/12", "tr"));

        assertFalse(h.contains("<script>alert"));
        assertFalse(h.contains("<img src=x"));
        assertFalse(h.contains("onerror=alert(2)>"));
        assertTrue(h.contains("&lt;script&gt;alert(1)&lt;/script&gt;&quot;&gt;&lt;img src=x onerror=alert(2)&gt; &amp; &#39;x&#39;"));
    }

    @Test
    void pageLanguageFollowsAcceptLanguage() throws Exception {
        when(shares.publicView(any())).thenReturn(Optional.of(news("T", "D", null)));

        String en = body(call("/s/n/12", "en"));
        String ar = body(call("/s/n/12", "ar"));
        String tr = body(call("/s/n/12", "tr"));

        assertTrue(en.contains("<html lang=\"en\" dir=\"ltr\">"));
        assertTrue(en.contains("Open in app"));
        assertTrue(en.contains("https://bukampus.com.tr/en/download"));
        assertTrue(ar.contains("<html lang=\"ar\" dir=\"rtl\">"));
        assertTrue(ar.contains("افتح في التطبيق"));
        assertTrue(tr.contains("Uygulamada aç"));
    }

    @Test
    void postUsesTheDedicatedPublicImageEndpointAndEventShowsDate() throws Exception {
        when(shares.publicView(new ShareRef(ShareType.POST, 5))).thenReturn(Optional.of(new ShareService.Resolved(
                new ShareRef(ShareType.POST, 5), 9L, "Kampus bahar", "Ayse", "Kampus bahar", "/api/posts/media/55?thumb=true",
                55L, "PHOTO", Instant.now(), null)));
        when(shares.publicView(new ShareRef(ShareType.EVENT, 3))).thenReturn(Optional.of(new ShareService.Resolved(
                new ShareRef(ShareType.EVENT, 3), null, "Bahar Senligi", "Fotograf Kulubu", null, "/files/events/ab.jpg",
                null, null, Instant.parse("2026-11-20T10:00:00Z"), "Merkez Kampus")));

        String post = body(call("/s/p/5", "tr"));
        String ev = body(call("/s/e/3", "tr"));

        assertTrue(post.contains("og:image\" content=\"https://bukampus.com.tr/s/p/5/img\""));
        assertTrue(ev.contains("og:image\" content=\"https://bukampus.com.tr/files/events/ab.jpg\""));
        assertTrue(ev.contains("20 Kasım 2026, 13:00 · Merkez Kampus"), ev);
    }

    @Test
    void rateLimitedClientsGetNeutral429WithRetryAfterAndNoDataAccess() throws Exception {
        doThrow(new RateLimitedException(42)).when(limiter).check(anyString(), anyInt(), any());

        MockHttpServletResponse r = call("/s/p/5", "tr");

        assertEquals(429, r.getStatus());
        assertEquals("42", r.getHeader("Retry-After"));
        assertEquals("no-store", r.getHeader("Cache-Control"));
        verify(shares, never()).publicView(any());
    }

    @Test
    void redisFailureDoesNotBreakThePage() throws Exception {
        doThrow(new IllegalStateException("redis down")).when(limiter).check(anyString(), anyInt(), any());
        when(shares.publicView(any())).thenReturn(Optional.of(news("T", "D", null)));

        assertEquals(200, call("/s/n/12", null).getStatus());
    }

    @Test
    void imageEndpointServesOnlyPublicPostPreviewsElseFallsBackToNotFound() throws Exception {
        when(shares.publicView(new ShareRef(ShareType.POST, 5))).thenReturn(Optional.of(new ShareService.Resolved(
                new ShareRef(ShareType.POST, 5), 9L, "t", null, null, null, 55L, "PHOTO", Instant.now(), null)));
        when(shares.publicView(new ShareRef(ShareType.POST, 6))).thenReturn(Optional.empty());
        when(postMedia.servePublicPreview(eq(55L), any())).thenReturn(ResponseEntity.ok().build());

        assertEquals(200, call("/s/p/5/img", null).getStatus());
        assertEquals(404, call("/s/p/6/img", null).getStatus());
        assertEquals(404, call("/s/n/5/img", null).getStatus()); // haber gorseli bu uctan sunulmaz
        assertEquals(404, call("/s/p/abc/img", null).getStatus());
    }
}
