package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import org.junit.jupiter.api.Test;

/** Yogunluk/hiz sinirlama hatalari (DB_TIMEOUT 503, RATE_LIMITED 429 + Retry-After) uc dilde ceviriye sahip olmali. */
class ThrottleErrorsI18nTest {

    private static String value(String file, String key) throws Exception {
        try (InputStream in = ThrottleErrorsI18nTest.class.getResourceAsStream("/i18n/" + file)) {
            Properties p = new Properties();
            p.load(new InputStreamReader(in, StandardCharsets.UTF_8));
            return p.getProperty(key);
        }
    }

    @Test
    void dbTimeoutTranslatedInAllLanguages() throws Exception {
        for (String f : new String[] {"ops.properties", "ops_en.properties", "ops_ar.properties"}) {
            String v = value(f, "error.DB_TIMEOUT");
            assertFalse(v == null || v.isBlank(), f);
        }
    }

    @Test
    void rateLimitedTranslatedInAllLanguages() throws Exception {
        for (String f : new String[] {"messages.properties", "messages_en.properties", "messages_ar.properties"}) {
            String v = value(f, "error.RATE_LIMITED");
            assertFalse(v == null || v.isBlank(), f);
        }
    }

    @Test
    void rateLimitedHandlerSets429WithRetryAfter() {
        I18n i18n = mock(I18n.class);
        when(i18n.error(anyString(), anyString(), any(), any())).thenReturn("cok fazla");
        var res = new ApiExceptionHandler(i18n).rateLimited(new RateLimitedException(7));
        assertEquals(429, res.getStatusCode().value());
        assertEquals("7", res.getHeaders().getFirst("Retry-After"));
        assertEquals("RATE_LIMITED", res.getBody().get("code"));
    }
}
