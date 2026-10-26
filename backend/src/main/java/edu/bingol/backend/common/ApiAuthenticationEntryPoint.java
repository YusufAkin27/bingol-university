package edu.bingol.backend.common;

import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

/**
 * Kimliksiz istekte 401 + `{"code":"UNAUTHORIZED","message":...}` yazar (diger hatalarla ayni bicim).
 * SecurityConfig'te `exceptionHandling(e -> e.authenticationEntryPoint(entryPoint))` ile baglanir
 * (bkz. docs/changes/ops.md); Basic auth icin WWW-Authenticate basligi korunur.
 */
@Component
public class ApiAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final I18n i18n;

    public ApiAuthenticationEntryPoint(I18n i18n) {
        this.i18n = i18n;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException ex)
            throws IOException {
        String message = i18n.error("UNAUTHORIZED", "Giriş gerekli.", LocaleContextHolder.getLocale(), new Object[0]);
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setHeader("WWW-Authenticate", "Basic realm=\"admin\"");
        response.setContentType("application/json");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"code\":\"UNAUTHORIZED\",\"message\":\"" + escape(message) + "\"}");
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
