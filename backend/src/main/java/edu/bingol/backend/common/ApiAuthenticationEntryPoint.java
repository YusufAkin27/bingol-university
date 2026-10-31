package edu.bingol.backend.common;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

/**
 * Kimliksiz istekte standart hata zarfini yazar: 401 {@code {code,message,traceId}} (UNAUTHORIZED / SESSION_REPLACED)
 * ya da Redis kesikken kimlik dogrulanamadiysa 503 REDIS_UNAVAILABLE + Retry-After (T-003). SecurityConfig'te TEK
 * giris noktasi olarak baglanir (/api/** ve /api/admin/** dahil).
 *
 * <p>{@code WWW-Authenticate: Basic} YALNIZ yonetici Basic auth acikken, /api/admin/** yolunda, Authorization basligi
 * HIC olmayan ve tarayici fetch/XHR olmayan (curl, adres cubugu) isteklere yazilir. Bozuk/suresi dolmus Bearer ya
 * da JSON isteyen istemciye (yonetim paneli) ASLA yazilmaz: tarayici yerel Basic parola penceresi acip paneli
 * dondururdu (T-004).
 */
@Component
public class ApiAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ApiErrorWriter writer;
    private final boolean adminBasic;

    public ApiAuthenticationEntryPoint(I18n i18n) {
        this(new ApiErrorWriter(i18n), true);
    }

    @Autowired
    public ApiAuthenticationEntryPoint(ApiErrorWriter writer,
                                       @Value("${app.security.admin-basic.enabled:true}") boolean adminBasic) {
        this.writer = writer;
        this.adminBasic = adminBasic;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException ex)
            throws IOException {
        Object down = request.getAttribute(JwtAuthFilter.REDIS_UNAVAILABLE_ATTR);
        if (down != null) {
            long retry = down instanceof Number n ? n.longValue() : 5;
            writer.write(request, response, 503, "REDIS_UNAVAILABLE", null, retry);
            return;
        }
        // Imzali ama iptal edilmis token (baska cihaz girisi, tum oturumlari kapatma): istemci ayirt edebilsin.
        boolean replaced = request.getAttribute(JwtAuthFilter.SESSION_REPLACED_ATTR) != null;
        if (wantsBasicChallenge(request)) {
            response.setHeader("WWW-Authenticate", "Basic realm=\"admin\"");
        }
        writer.write(request, response, 401, replaced ? "SESSION_REPLACED" : "UNAUTHORIZED", null, -1);
    }

    /** Bkz. sinif aciklamasi: yalniz basliksiz, tarayici-disi Basic istemci. */
    boolean wantsBasicChallenge(HttpServletRequest request) {
        if (!adminBasic || request.getHeader("Authorization") != null) {
            return false;
        }
        String uri = request.getRequestURI();
        if (uri == null || !uri.startsWith("/api/admin/")) {
            return false;
        }
        String accept = request.getHeader("Accept");
        if (accept != null && accept.toLowerCase(java.util.Locale.ROOT).contains("application/json")) {
            return false;
        }
        String dest = request.getHeader("Sec-Fetch-Dest"); // fetch/XHR: "empty"; adres cubugu: "document"
        return dest == null || "document".equalsIgnoreCase(dest);
    }
}
