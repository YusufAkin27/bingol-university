package edu.bingol.backend.common.web;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletInputStream;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RequestBodyLimitFilterTest {

    private final I18n i18n = mock(I18n.class);
    private final RequestBodyLimitFilter filter = new RequestBodyLimitFilter(i18n, 64 * 1024, 2 * 1024 * 1024,
            55L * 1024 * 1024);

    /** Content-Length'i sahte iceriksiz bildiren istek (milyonlarca bayt ayirmadan). */
    private static MockHttpServletRequest declared(String method, String uri, long contentLength) {
        return new MockHttpServletRequest(method, uri) {
            @Override
            public long getContentLengthLong() {
                return contentLength;
            }
        };
    }

    private MockHttpServletResponse run(String method, String uri, long contentLength) throws Exception {
        MockHttpServletRequest req = declared(method, uri, contentLength);
        req.setContentType("application/json");
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();
        when(i18n.msg(anyString(), any(java.util.Locale.class))).thenReturn("Istek govdesi cok buyuk.");
        filter.doFilter(req, res, chain);
        lastChainCalled = chain.getRequest() != null;
        return res;
    }

    private boolean lastChainCalled;

    @Test
    void oversizedJsonOnUnauthenticatedEndpointIs413BeforeAnyParsing() throws Exception {
        MockHttpServletResponse res = run("POST", "/api/auth/login", 20L * 1024 * 1024);
        assertEquals(413, res.getStatus());
        assertTrue(res.getContentAsString().contains("\"code\":\"PAYLOAD_TOO_LARGE\""));
        assertEquals(false, lastChainCalled);
    }

    @Test
    void smallJsonPasses() throws Exception {
        MockHttpServletResponse res = run("POST", "/api/auth/login", 300);
        assertEquals(200, res.getStatus());
        assertTrue(lastChainCalled);
    }

    @Test
    void defaultLimitIs64Kb() {
        assertEquals(65536, filter.limitFor("POST", "/api/auth/register"));
        assertEquals(65536, filter.limitFor("PUT", "/api/public/support/tickets"));
        assertEquals(65536, filter.limitFor("POST", "/api/conversations/5/messages"));
    }

    @Test
    void uploadPathsGetTheLargeLimitOthersDoNot() {
        long big = 55L * 1024 * 1024;
        assertEquals(big, filter.limitFor("POST", "/api/conversations/12/media"));
        assertEquals(big, filter.limitFor("POST", "/api/posts/media"));
        assertEquals(big, filter.limitFor("POST", "/api/users/me/avatar"));
        assertEquals(big, filter.limitFor("PUT", "/api/events/3/cover"));
        assertEquals(big, filter.limitFor("POST", "/api/communities/3/posts/upload"));
        // benzer ama allowlist disi yollar kucuk kalir
        assertEquals(65536, filter.limitFor("POST", "/api/conversations/12/media/extra"));
        assertEquals(65536, filter.limitFor("POST", "/api/conversations/12/messages"));
        assertEquals(65536, filter.limitFor("POST", "/api/auth/media"));
    }

    @Test
    void adminAndAnalyticsHaveTheirOwnClassesAndGetIsUnlimited() {
        assertEquals(2 * 1024 * 1024, filter.limitFor("POST", "/api/admin/mail/campaigns"));
        assertEquals(256 * 1024, filter.limitFor("POST", "/api/analytics/events"));
        assertEquals(-1, filter.limitFor("GET", "/api/news"));
        assertEquals(-1, filter.limitFor("POST", "/actuator/health"));
    }

    @Test
    void uploadPathAcceptsLargeDeclaredBodyButNotBeyondTheCap() throws Exception {
        MockHttpServletRequest req = declared("POST", "/api/conversations/9/media", 40L * 1024 * 1024);
        req.setContentType("multipart/form-data; boundary=x");
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(req, new MockHttpServletResponse(), chain);
        assertNotNull(chain.getRequest());

        MockHttpServletRequest big = declared("POST", "/api/conversations/9/media", 80L * 1024 * 1024);
        big.setContentType("multipart/form-data; boundary=x");
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain2 = new MockFilterChain();
        when(i18n.msg(anyString(), any(java.util.Locale.class))).thenReturn("x");
        filter.doFilter(big, res, chain2);
        assertEquals(413, res.getStatus());
        assertEquals(null, chain2.getRequest());
    }

    @Test
    void chunkedBodyWithoutContentLengthIsCountedAndAborted() throws Exception {
        // Content-Length bildirilmeyen (parcali) govde: akis sayilir, sinir asilinca RequestBodyTooLargeException
        MockHttpServletRequest req = declared("POST", "/api/auth/login", -1);
        req.setContentType("application/json");
        req.setContent(new byte[100_000]);
        boolean chunked = true;
        AtomicReference<Throwable> error = new AtomicReference<>();
        filter.doFilter(req, new MockHttpServletResponse(), (request, response) -> {
            try {
                ((jakarta.servlet.http.HttpServletRequest) request).getInputStream().readAllBytes();
            } catch (IOException e) {
                error.set(e);
            }
        });
        if (chunked) {
            assertTrue(error.get() instanceof RequestBodyTooLargeException);
        }
    }

    @Test
    void countingStreamThrowsOnceTheLimitIsExceeded() throws Exception {
        byte[] data = new byte[1000];
        ServletInputStream raw = new ServletInputStream() {
            private final ByteArrayInputStream in = new ByteArrayInputStream(data);

            @Override
            public int read() {
                return in.read();
            }

            @Override
            public boolean isFinished() {
                return in.available() == 0;
            }

            @Override
            public boolean isReady() {
                return true;
            }

            @Override
            public void setReadListener(ReadListener readListener) {
            }
        };
        var counting = new RequestBodyLimitFilter.CountingStream(raw, 600);
        byte[] buf = new byte[400];
        assertEquals(400, counting.read(buf, 0, 400));
        assertThrows(RequestBodyTooLargeException.class, () -> counting.read(buf, 0, 400));
    }
}
