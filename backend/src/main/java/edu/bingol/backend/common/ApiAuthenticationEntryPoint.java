package edu.bingol.backend.common;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
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
        // Imzali ama iptal edilmis token (baska cihaz girisi, tum oturumlari kapatma): istemci ayirt edebilsin.
        boolean replaced = request.getAttribute(JwtAuthFilter.SESSION_REPLACED_ATTR) != null;
        String code = replaced ? "SESSION_REPLACED" : "UNAUTHORIZED";
        String message = replaced
                ? i18n.error(code, "Hesabınıza başka bir cihazdan giriş yapıldı.", LocaleContextHolder.getLocale(), new Object[0])
                : i18n.error(code, "Giriş gerekli.", LocaleContextHolder.getLocale(), new Object[0]);
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setHeader("WWW-Authenticate", "Basic realm=\"admin\"");
        response.setContentType("application/json");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"code\":\"" + code + "\",\"message\":\"" + escape(message) + "\"}");
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
