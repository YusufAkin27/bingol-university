package edu.bingol.backend.common;

import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.stereotype.Component;

/**
 * DispatcherServlet DISINDA (guvenlik filtreleri, /error) standart hata zarfini yazar:
 * {@code {"code","message","traceId"}} + {@code Content-Language} + {@code Vary: Accept-Language}.
 * Controller hatalari {@link ApiExceptionHandler}'dan ayni bicimde cikar (T-004).
 */
@Component
public class ApiErrorWriter {

    private final I18n i18n;

    public ApiErrorWriter(I18n i18n) {
        this.i18n = i18n;
    }

    /** HTTP durumundan makine kodu (bilinmeyen durum icin HTTP_&lt;kod&gt;). */
    public static String codeFor(int status) {
        return switch (status) {
            case 400 -> "MALFORMED_REQUEST";
            case 401 -> "UNAUTHORIZED";
            case 403 -> "FORBIDDEN";
            case 404 -> "NOT_FOUND";
            case 405 -> "METHOD_NOT_ALLOWED";
            case 406 -> "NOT_ACCEPTABLE";
            case 413 -> "PAYLOAD_TOO_LARGE";
            case 415 -> "UNSUPPORTED_MEDIA_TYPE";
            case 429 -> "RATE_LIMITED";
            case 503 -> "SERVICE_UNAVAILABLE";
            default -> status >= 500 ? "INTERNAL_ERROR" : "HTTP_" + status;
        };
    }

    /** Varsayilan Turkce metin (ceviri anahtari yoksa). */
    private static String defaultMessage(String code) {
        return switch (code) {
            case "UNAUTHORIZED" -> "Giriş gerekli.";
            case "SESSION_REPLACED" -> "Hesabınıza başka bir cihazdan giriş yapıldı.";
            case "FORBIDDEN" -> "Bu işlem için yetkiniz yok.";
            case "NOT_FOUND" -> "Bulunamadı.";
            case "METHOD_NOT_ALLOWED" -> "Bu yöntem bu adreste desteklenmiyor.";
            case "NOT_ACCEPTABLE" -> "İstenen içerik türü sunulamıyor.";
            case "UNSUPPORTED_MEDIA_TYPE" -> "Desteklenmeyen içerik türü.";
            case "MALFORMED_REQUEST" -> "İstek biçimi geçersiz.";
            case "PAYLOAD_TOO_LARGE" -> "İstek gövdesi çok büyük.";
            case "REDIS_UNAVAILABLE" -> "Sistem geçici olarak kullanılamıyor. Lütfen birkaç saniye sonra tekrar deneyin.";
            case "INTERNAL_ERROR" -> "Beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.";
            default -> "İşlem tamamlanamadı.";
        };
    }

    /** Durum koduna uygun varsayilan kodla yazar. */
    public void write(HttpServletRequest req, HttpServletResponse res, int status) throws IOException {
        write(req, res, status, codeFor(status), null, -1);
    }

    /**
     * @param message null ise {@code error.<code>} cevirisi kullanilir
     * @param retryAfter &gt; 0 ise Retry-After basligi
     */
    public void write(HttpServletRequest req, HttpServletResponse res, int status, String code, String message,
                      long retryAfter) throws IOException {
        Locale locale = LocaleContextHolder.getLocale();
        String text = message != null ? message : i18n.error(code, defaultMessage(code), locale, new Object[0]);
        res.setStatus(status);
        if (retryAfter > 0) {
            res.setHeader("Retry-After", String.valueOf(retryAfter));
        }
        res.setHeader("Content-Language", locale.getLanguage());
        res.addHeader("Vary", "Accept-Language");
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        // MDC hata yonlendirmesi (/error) sirasinda temizlenmis olabilir: yanit basligindaki kimlik yedektir
        String traceId = org.slf4j.MDC.get("requestId");
        if (traceId == null) {
            traceId = res.getHeader("X-Request-Id");
        }
        String trace = traceId == null ? "" : ",\"traceId\":\"" + escape(traceId) + "\"";
        res.getWriter().write("{\"code\":\"" + escape(code) + "\",\"message\":\"" + escape(text) + "\"" + trace + "}");
    }

    static String escape(String s) {
        StringBuilder sb = new StringBuilder(s.length() + 8);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\\' -> sb.append("\\\\");
                case '"' -> sb.append("\\\"");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.toString();
    }
}
