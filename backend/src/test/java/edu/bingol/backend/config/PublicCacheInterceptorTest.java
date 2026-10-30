package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/** HTTP onbellek basliklari: yalniz beyaz listedeki herkese-ayni uclar; Authorization'li istekte public YOK. */
class PublicCacheInterceptorTest {

    private final PublicCacheInterceptor interceptor = new PublicCacheInterceptor(CacheProperties.defaults());

    private MockHttpServletResponse run(PublicCacheInterceptor i, String method, String uri, boolean auth, int status,
                                        String existingCacheControl) {
        MockHttpServletRequest req = new MockHttpServletRequest(method, uri);
        if (auth) {
            req.addHeader("Authorization", "Bearer x");
        }
        MockHttpServletResponse res = new MockHttpServletResponse();
        res.setStatus(status);
        if (existingCacheControl != null) {
            res.setHeader("Cache-Control", existingCacheControl);
        }
        i.postHandle(req, res, new Object(), null);
        return res;
    }

    @Test
    void anonymousGetGetsPublicHeaderWithStaleWhileRevalidate() {
        MockHttpServletResponse res = run(interceptor, "GET", "/api/menu/today", false, 200, null);
        assertEquals("public, max-age=300, stale-while-revalidate=600", res.getHeader("Cache-Control"));
        assertEquals("Accept-Language", res.getHeader("Vary"));
    }

    @Test
    void authorizedRequestNeverGetsPublic() {
        MockHttpServletResponse res = run(interceptor, "GET", "/api/news", true, 200, null);
        assertEquals("private, max-age=60", res.getHeader("Cache-Control"));
    }

    @Test
    void whitelistCoversPublicReadEndpointsOnly() {
        assertNotNull(PublicCacheInterceptor.policyFor("/api/news"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/news/123"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/menu"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/status"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/app/info"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/faq"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/legal"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/legal/TERMS"));
        assertNotNull(PublicCacheInterceptor.policyFor("/api/legal/community-rules"));
        // kullaniciya ozel / yazma uclari asla
        assertNull(PublicCacheInterceptor.policyFor("/api/legal/consents"));
        assertNull(PublicCacheInterceptor.policyFor("/api/legal/acceptance-status"));
        assertNull(PublicCacheInterceptor.policyFor("/api/legal/accept"));
        assertNull(PublicCacheInterceptor.policyFor("/api/news/abc"));
        assertNull(PublicCacheInterceptor.policyFor("/api/me"));
        assertNull(PublicCacheInterceptor.policyFor("/api/conversations"));
        assertNull(PublicCacheInterceptor.policyFor("/api/notifications"));
        assertNull(PublicCacheInterceptor.policyFor("/api/events/featured"));
        assertNull(PublicCacheInterceptor.policyFor("/api/admin/settings"));
    }

    @Test
    void errorsAndNonGetAreLeftAlone() {
        assertNull(run(interceptor, "GET", "/api/news/5", false, 404, null).getHeader("Cache-Control"));
        assertNull(run(interceptor, "GET", "/api/menu", false, 400, null).getHeader("Cache-Control"));
        assertNull(run(interceptor, "POST", "/api/news", false, 200, null).getHeader("Cache-Control"));
        assertNull(run(interceptor, "GET", "/api/menu/today", false, 204, null).getHeader("Cache-Control"));
    }

    @Test
    void existingCacheControlIsPreserved() {
        MockHttpServletResponse res = run(interceptor, "GET", "/api/news", false, 200, "no-store");
        assertEquals("no-store", res.getHeader("Cache-Control"));
    }

    @Test
    void disabledCacheAddsNoHeaders() {
        PublicCacheInterceptor off = new PublicCacheInterceptor(CacheProperties.defaults().withEnabled(false));
        assertNull(run(off, "GET", "/api/news", false, 200, null).getHeader("Cache-Control"));
    }
}
