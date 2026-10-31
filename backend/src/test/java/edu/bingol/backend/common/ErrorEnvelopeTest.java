package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.RequestDispatcher;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;

/** T-004: her hata {code,message,traceId} zarfi + Content-Language/Vary; Basic challenge yalniz basliksiz Basic istemciye. */
class ErrorEnvelopeTest {

    private final I18n i18n = mock(I18n.class);
    private final ApiExceptionHandler handler = new ApiExceptionHandler(i18n);

    ErrorEnvelopeTest() {
        when(i18n.error(anyString(), anyString(), any(), any())).thenAnswer(i -> i.getArgument(1));
    }

    @AfterEach
    void clear() {
        MDC.clear();
    }

    @Test
    void uncaughtExceptionBecomes500InternalErrorWithTraceIdAndNoDetails() throws Exception {
        MDC.put("requestId", "req-123");

        var res = handler.unexpected(new IllegalStateException("secret internal detail"));

        assertEquals(500, res.getStatusCode().value());
        assertEquals("INTERNAL_ERROR", res.getBody().get("code"));
        assertEquals("req-123", res.getBody().get("traceId"));
        assertFalse(res.getBody().get("message").contains("secret"));
        assertEquals(MediaType.APPLICATION_JSON, res.getHeaders().getContentType());
        assertNotNull(res.getHeaders().getFirst("Content-Language"));
        assertEquals("Accept-Language", res.getHeaders().getFirst("Vary"));
    }

    @Test
    void methodNotAllowedKeepsAllowHeaderAndGetsEnvelope() throws Exception {
        var res = handler.unexpected(new HttpRequestMethodNotSupportedException("DELETE", List.of("GET", "HEAD")));

        assertEquals(405, res.getStatusCode().value());
        assertEquals("METHOD_NOT_ALLOWED", res.getBody().get("code"));
        assertTrue(res.getHeaders().getFirst("Allow").contains("GET"));
    }

    @Test
    void unsupportedMediaTypeAndNotFoundGetEnvelopes() throws Exception {
        var unsupported = handler.unexpected(
                new HttpMediaTypeNotSupportedException(MediaType.TEXT_PLAIN, List.of(MediaType.APPLICATION_JSON)));
        var notFound = handler.unexpected(new org.springframework.web.ErrorResponseException(HttpStatus.NOT_FOUND));

        assertEquals(415, unsupported.getStatusCode().value());
        assertEquals("UNSUPPORTED_MEDIA_TYPE", unsupported.getBody().get("code"));
        assertEquals(404, notFound.getStatusCode().value());
        assertEquals("NOT_FOUND", notFound.getBody().get("code"));
    }

    @Test
    void springSecurityExceptionsAreLeftToTheSecurityChain() {
        assertThrows(AccessDeniedException.class, () -> handler.unexpected(new AccessDeniedException("x")));
        assertThrows(BadCredentialsException.class, () -> handler.unexpected(new BadCredentialsException("x")));
    }

    @Test
    void redisFailureInsideAControllerIs503WithRetryAfterAndOpensTheBreaker() throws Exception {
        RedisBreaker breaker = new RedisBreaker(5000);
        handler.setBreaker(breaker);

        var res = handler.unexpected(new org.springframework.data.redis.RedisConnectionFailureException("down"));

        assertEquals(503, res.getStatusCode().value());
        assertEquals("REDIS_UNAVAILABLE", res.getBody().get("code"));
        assertNotNull(res.getHeaders().getFirst("Retry-After"));
        assertTrue(breaker.isOpen());
        // DB zaman asimi ile karismaz
        var db = handler.dbTimeout(new org.springframework.dao.QueryTimeoutException("57014"));
        assertEquals("DB_TIMEOUT", db.getBody().get("code"));
    }

    @Test
    void redisUnavailableExceptionKeepsItsRetryAfter() {
        var res = handler.redisUnavailable(new RedisUnavailableException(7));

        assertEquals(503, res.getStatusCode().value());
        assertEquals("7", res.getHeaders().getFirst("Retry-After"));
    }

    @Test
    void containerErrorControllerWritesTheEnvelopeForEveryStatus() throws Exception {
        ApiErrorController c = new ApiErrorController(new ApiErrorWriter(i18n));
        MDC.put("requestId", "req-9");
        for (int status : new int[] {400, 401, 403, 404, 405, 415, 500}) {
            MockHttpServletRequest req = new MockHttpServletRequest("GET", "/error");
            req.setAttribute(RequestDispatcher.ERROR_STATUS_CODE, status);
            MockHttpServletResponse res = new MockHttpServletResponse();

            c.error(req, res);

            assertEquals(status, res.getStatus());
            String body = res.getContentAsString();
            assertTrue(body.contains("\"code\":\"" + ApiErrorWriter.codeFor(status) + "\""), body);
            assertTrue(body.contains("\"traceId\":\"req-9\""), body);
            assertTrue(res.getContentType().startsWith("application/json"));
            assertEquals("Accept-Language", res.getHeader("Vary"));
            assertNull(res.getHeader("WWW-Authenticate"));
        }
        // bilinmeyen/eksik durum 500
        MockHttpServletResponse missing = new MockHttpServletResponse();
        c.error(new MockHttpServletRequest("POST", "/error"), missing);
        assertEquals(500, missing.getStatus());
        assertTrue(missing.getContentAsString().contains("INTERNAL_ERROR"));
    }

    @Test
    void errorWriterEscapesQuotesAndControlCharacters() {
        assertEquals("a\\\"b\\\\c\\n\\u0001", ApiErrorWriter.escape("a\"b\\c\n\u0001"));
    }

    // ---- WWW-Authenticate: Basic

    private MockHttpServletResponse commence(boolean basicEnabled, MockHttpServletRequest req) throws Exception {
        ApiAuthenticationEntryPoint ep = new ApiAuthenticationEntryPoint(new ApiErrorWriter(i18n), basicEnabled);
        MockHttpServletResponse res = new MockHttpServletResponse();
        ep.commence(req, res, new BadCredentialsException("x"));
        return res;
    }

    @Test
    void basicChallengeOnlyForHeaderlessNonBrowserAdminRequests() throws Exception {
        // curl: Authorization yok, Accept */*
        MockHttpServletResponse curl = commence(true, new MockHttpServletRequest("GET", "/api/admin/users"));
        assertEquals(401, curl.getStatus());
        assertEquals("Basic realm=\"admin\"", curl.getHeader("WWW-Authenticate"));
        assertTrue(curl.getContentAsString().contains("\"code\":\"UNAUTHORIZED\""));
    }

    @Test
    void neverChallengeWhenABearerOrAnyAuthorizationHeaderIsPresent() throws Exception {
        MockHttpServletRequest bad = new MockHttpServletRequest("GET", "/api/admin/users");
        bad.addHeader("Authorization", "Bearer bozuk.token.degeri");

        MockHttpServletResponse res = commence(true, bad);

        assertEquals(401, res.getStatus());
        assertNull(res.getHeader("WWW-Authenticate"), "bozuk Bearer'a Basic penceresi acilmamali");
        assertTrue(res.getContentAsString().contains("\"code\":\"UNAUTHORIZED\""));
        MockHttpServletRequest basic = new MockHttpServletRequest("GET", "/api/admin/users");
        basic.addHeader("Authorization", "Basic YWRtaW46eA==");
        assertNull(commence(true, basic).getHeader("WWW-Authenticate"));
    }

    @Test
    void neverChallengeForJsonFetchNonAdminPathsOrWhenBasicIsDisabled() throws Exception {
        MockHttpServletRequest json = new MockHttpServletRequest("GET", "/api/admin/users");
        json.addHeader("Accept", "application/json");
        assertNull(commence(true, json).getHeader("WWW-Authenticate"));

        MockHttpServletRequest fetch = new MockHttpServletRequest("GET", "/api/admin/users");
        fetch.addHeader("Sec-Fetch-Dest", "empty");
        assertNull(commence(true, fetch).getHeader("WWW-Authenticate"));

        assertNull(commence(true, new MockHttpServletRequest("GET", "/api/profile")).getHeader("WWW-Authenticate"));
        assertNull(commence(false, new MockHttpServletRequest("GET", "/api/admin/users")).getHeader("WWW-Authenticate"));
    }
}
