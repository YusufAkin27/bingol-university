package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import org.junit.jupiter.api.Test;
import org.springframework.dao.QueryTimeoutException;

class DbTimeoutHandlerTest {

    @Test
    void queryTimeoutBecomes503WithRetryAfter() {
        I18n i18n = mock(I18n.class);
        when(i18n.error(anyString(), anyString(), any(), any())).thenReturn("yogun");
        var res = new ApiExceptionHandler(i18n).dbTimeout(new QueryTimeoutException("57014"));
        assertEquals(503, res.getStatusCode().value());
        assertEquals("5", res.getHeaders().getFirst("Retry-After"));
        assertEquals("DB_TIMEOUT", res.getBody().get("code"));
    }

    @Test
    void cannotCreateTransactionBecomes503() throws Exception {
        I18n i18n = mock(I18n.class);
        when(i18n.error(anyString(), anyString(), any(), any())).thenReturn("yogun");
        var m = ApiExceptionHandler.class.getDeclaredMethod("dbTimeout", Exception.class).getAnnotation(org.springframework.web.bind.annotation.ExceptionHandler.class);
        assertEquals(true, java.util.Arrays.asList(m.value()).contains(org.springframework.transaction.CannotCreateTransactionException.class));
        var res = new ApiExceptionHandler(i18n).dbTimeout(new org.springframework.transaction.CannotCreateTransactionException("havuz dolu"));
        assertEquals(503, res.getStatusCode().value());
        assertEquals("DB_TIMEOUT", res.getBody().get("code"));
    }
}
