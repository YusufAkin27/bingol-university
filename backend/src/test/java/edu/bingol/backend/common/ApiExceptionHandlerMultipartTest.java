package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import org.junit.jupiter.api.Test;
import org.springframework.web.multipart.MultipartException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

class ApiExceptionHandlerMultipartTest {

    private final I18n i18n = mock(I18n.class);
    private final ApiExceptionHandler handler = new ApiExceptionHandler(i18n);

    @Test
    void nonMultipartRequestsAreBadRequest() {
        when(i18n.error(anyString(), anyString(), any(), any())).thenReturn("x");
        assertEquals(400, handler.malformed(new MultipartException("not multipart")).getStatusCode().value());
        assertEquals(400, handler.malformed(new MissingServletRequestPartException("file")).getStatusCode().value());
    }
}
