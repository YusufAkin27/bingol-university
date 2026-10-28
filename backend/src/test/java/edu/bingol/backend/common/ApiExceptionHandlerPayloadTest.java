package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.web.RequestBodyTooLargeException;
import edu.bingol.backend.i18n.I18n;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpInputMessage;
import org.springframework.http.converter.HttpMessageNotReadableException;

class ApiExceptionHandlerPayloadTest {

    @Test
    void streamLimitInsideUnreadableExceptionMapsTo413() {
        I18n messages = mock(I18n.class);
        when(messages.error(anyString(), anyString(), any(), any())).thenReturn("cok buyuk");
        var handler = new ApiExceptionHandler(messages);
        var wrapped = new HttpMessageNotReadableException("x",
                new RuntimeException(new RequestBodyTooLargeException(10)), mock(HttpInputMessage.class));

        var res = handler.malformed(wrapped);

        assertEquals(413, res.getStatusCode().value());
        assertEquals("PAYLOAD_TOO_LARGE", res.getBody().get("code"));
    }

    @Test
    void plainMalformedBodyStays400() {
        I18n messages = mock(I18n.class);
        when(messages.error(anyString(), anyString(), any(), any())).thenReturn("bozuk");
        var res = new ApiExceptionHandler(messages).malformed(
                new HttpMessageNotReadableException("x", mock(HttpInputMessage.class)));
        assertEquals(400, res.getStatusCode().value());
        assertEquals("MALFORMED_REQUEST", res.getBody().get("code"));
    }
}
