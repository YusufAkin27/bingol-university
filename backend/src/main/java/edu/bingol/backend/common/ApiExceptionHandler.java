package edu.bingol.backend.common;

import edu.bingol.backend.i18n.I18n;
import java.util.Locale;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;

/** Tum hatalari `{"code","message"}` govdesine cevirir; mesaj istek dilindedir (Accept-Language: tr|en|ar). */
@RestControllerAdvice
public class ApiExceptionHandler {

    private final I18n i18n;

    public ApiExceptionHandler(I18n i18n) {
        this.i18n = i18n;
    }

    @ExceptionHandler(ApiException.class)
    ResponseEntity<Map<String, String>> api(ApiException e) {
        if (e instanceof FieldApiException f) { // alana bagli hata: {code,message,field}
            return ResponseEntity.status(f.status()).body(withTrace(Map.of("code", f.code(), "field", f.field(),
                    "message", i18n.error(f.code(), f.getMessage(), locale(), f.args()))));
        }
        return body(e.status(), e.code(), i18n.error(e.code(), e.getMessage(), locale(), e.args()));
    }

    @ExceptionHandler(RateLimitedException.class)
    ResponseEntity<Map<String, String>> rateLimited(RateLimitedException e) {
        return ResponseEntity.status(e.status()).header(HttpHeaders.RETRY_AFTER, String.valueOf(e.retryAfterSeconds()))
                .body(withTrace(Map.of("code", e.code(), "message", i18n.error(e.code(), e.getMessage(), locale(), e.args()))));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, String>> validation(MethodArgumentNotValidException e) {
        // Kisit mesajlari dogrulayici tarafindan istek dilinde uretilir.
        String msg = e.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + ": " + f.getDefaultMessage()).findFirst()
                .orElse(i18n.error("VALIDATION_ERROR", "Geçersiz istek", locale(), new Object[0]));
        return body(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", msg);
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MissingServletRequestParameterException.class,
            MethodArgumentTypeMismatchException.class, MultipartException.class,
            MissingServletRequestPartException.class})
    ResponseEntity<Map<String, String>> malformed(Exception e) {
        return body(HttpStatus.BAD_REQUEST, "MALFORMED_REQUEST",
                i18n.error("MALFORMED_REQUEST", "İstek biçimi geçersiz.", locale(), new Object[0]));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<Map<String, String>> tooLarge(MaxUploadSizeExceededException e) {
        return body(HttpStatus.PAYLOAD_TOO_LARGE, "FILE_TOO_LARGE",
                i18n.error("FILE_TOO_LARGE", "Dosya çok büyük.", locale(), new Object[] {"5"}));
    }

    /**
     * Veritabani zaman asimi / kilit zaman asimi / baglanti havuzu tukenmesi: 503 DB_TIMEOUT (Retry-After: 5).
     * statement_timeout (SQLSTATE 57014), lock_timeout (55P03) ve Hikari connectionTimeout buraya duser;
     * surec calismaya devam eder, istemci tekrar dener.
     */
    @ExceptionHandler({org.springframework.dao.QueryTimeoutException.class,
            org.springframework.dao.CannotAcquireLockException.class,
            org.springframework.dao.PessimisticLockingFailureException.class,
            org.springframework.dao.DataAccessResourceFailureException.class,
            org.springframework.jdbc.CannotGetJdbcConnectionException.class,
            jakarta.persistence.QueryTimeoutException.class,
            jakarta.persistence.LockTimeoutException.class,
            jakarta.persistence.PessimisticLockException.class})
    ResponseEntity<Map<String, String>> dbTimeout(Exception e) {
        org.slf4j.LoggerFactory.getLogger(ApiExceptionHandler.class).warn("DB_TIMEOUT: {}", e.toString());
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).header(HttpHeaders.RETRY_AFTER, "5")
                .body(withTrace(Map.of("code", "DB_TIMEOUT", "message",
                        i18n.error("DB_TIMEOUT", "Sistem şu an yoğun. Lütfen birkaç saniye sonra tekrar deneyin.", locale(), new Object[0]))));
    }

    private static Locale locale() {
        return LocaleContextHolder.getLocale();
    }

    private static ResponseEntity<Map<String, String>> body(HttpStatus status, String code, String message) {
        return ResponseEntity.status(status).body(withTrace(Map.of("code", code, "message", message)));
    }

    /** Korelasyon kimligi (X-Request-Id; RequestIdFilter MDC'ye koyar) varsa `traceId` olarak eklenir. */
    private static Map<String, String> withTrace(Map<String, String> body) {
        String id = org.slf4j.MDC.get("requestId");
        if (id == null) {
            return body;
        }
        Map<String, String> copy = new java.util.LinkedHashMap<>(body);
        copy.put("traceId", id);
        return copy;
    }
}
