package edu.bingol.backend.common;

import edu.bingol.backend.i18n.I18n;
import java.util.Locale;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.ErrorResponse;
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

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(ApiExceptionHandler.class);

    private final I18n i18n;
    /** Redis devre kesici (istege bagli: yoksa yalniz 503 doner, devre acilmaz). */
    private RedisBreaker breaker;

    public ApiExceptionHandler(I18n i18n) {
        this.i18n = i18n;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setBreaker(RedisBreaker breaker) {
        this.breaker = breaker;
    }

    @ExceptionHandler(ApiException.class)
    ResponseEntity<Map<String, String>> api(ApiException e) {
        if (e instanceof FieldApiException f) { // alana bagli hata: {code,message,field}
            return json(f.status().value()).body(withTrace(Map.of("code", f.code(), "field", f.field(),
                    "message", i18n.error(f.code(), f.getMessage(), locale(), f.args()))));
        }
        return body(e.status(), e.code(), i18n.error(e.code(), e.getMessage(), locale(), e.args()));
    }

    @ExceptionHandler(RateLimitedException.class)
    ResponseEntity<Map<String, String>> rateLimited(RateLimitedException e) {
        return json(e.status().value()).header(HttpHeaders.RETRY_AFTER, String.valueOf(e.retryAfterSeconds()))
                .body(withTrace(Map.of("code", e.code(), "message", i18n.error(e.code(), e.getMessage(), locale(), e.args()))));
    }

    /** Redis kesik (devre kesici / yarida kalan istek): 503 + Retry-After. */
    @ExceptionHandler(RedisUnavailableException.class)
    ResponseEntity<Map<String, String>> redisUnavailable(RedisUnavailableException e) {
        return json(503).header(HttpHeaders.RETRY_AFTER, String.valueOf(e.retryAfterSeconds()))
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
        if (edu.bingol.backend.common.web.RequestBodyTooLargeException.in(e)) {
            // Akis sayaci (RequestBodyLimitFilter) siniri astiysa bozuk istek degil, cok buyuk istek
            return body(HttpStatus.PAYLOAD_TOO_LARGE, "PAYLOAD_TOO_LARGE",
                    i18n.error("PAYLOAD_TOO_LARGE", "İstek gövdesi çok büyük.", locale(), new Object[0]));
        }
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
            // @Transactional metot baglanti alamazsa (havuz dolu/DB donmus) JpaTransactionManager bunu firlatir (yuk testi F2b: 500 donuyordu)
            org.springframework.transaction.CannotCreateTransactionException.class,
            org.springframework.transaction.TransactionTimedOutException.class,
            jakarta.persistence.QueryTimeoutException.class,
            jakarta.persistence.LockTimeoutException.class,
            jakarta.persistence.PessimisticLockException.class})
    ResponseEntity<Map<String, String>> dbTimeout(Exception e) {
        if (RedisBreaker.isRedisFailure(e)) {
            // Redis baglanti hatasi/zaman asimi de DataAccess ailesindendir: Redis kesintisi veritabani gibi gorunmesin.
            return redisDown(e);
        }
        log.warn("DB_TIMEOUT: {}", e.toString());
        return json(503).header(HttpHeaders.RETRY_AFTER, "5")
                .body(withTrace(Map.of("code", "DB_TIMEOUT", "message",
                        i18n.error("DB_TIMEOUT", "Sistem şu an yoğun. Lütfen birkaç saniye sonra tekrar deneyin.", locale(), new Object[0]))));
    }

    /** Controller icinde yakalanan Redis hatasi: devreyi acar, 503 REDIS_UNAVAILABLE doner. */
    ResponseEntity<Map<String, String>> redisDown(Exception e) {
        long retry = 5;
        if (breaker != null) {
            breaker.trip(e);
            retry = breaker.retryAfterSeconds();
        } else {
            log.warn("REDIS_UNAVAILABLE: {}", e.toString());
        }
        return json(503).header(HttpHeaders.RETRY_AFTER, String.valueOf(retry))
                .body(withTrace(Map.of("code", "REDIS_UNAVAILABLE", "message",
                        i18n.error("REDIS_UNAVAILABLE",
                                "Sistem geçici olarak kullanılamıyor. Lütfen birkaç saniye sonra tekrar deneyin.",
                                locale(), new Object[0]))));
    }

    /**
     * Cerceve hatalari (404 NoResourceFound, 405, 406, 415, eksik parametre...) {@link ErrorResponse} uygular:
     * durum + varsa Allow/Accept basliklariyla ayni {code,message,traceId} zarfina cevrilir. Diger her yakalanmamis
     * istisna 500 INTERNAL_ERROR + traceId olur (ayrinti yalniz log'da; HTML/stack govdesi sizmaz). Spring Security
     * istisnalari (403/401) guvenlik zincirine birakilir.
     */
    @ExceptionHandler(Exception.class)
    ResponseEntity<Map<String, String>> unexpected(Exception e) throws Exception {
        if (e instanceof org.springframework.security.access.AccessDeniedException
                || e instanceof org.springframework.security.core.AuthenticationException) {
            throw e;
        }
        if (RedisBreaker.isRedisFailure(e)) {
            return redisDown(e);
        }
        if (e instanceof ErrorResponse er) {
            int status = er.getStatusCode().value();
            String code = ApiErrorWriter.codeFor(status);
            var b = json(status);
            er.getHeaders().forEach((k, v) -> b.header(k, v.toArray(String[]::new)));
            return b.body(withTrace(Map.of("code", code, "message", i18n.error(code, defaultOf(code), locale(), new Object[0]))));
        }
        if (isClientAbort(e)) {
            log.debug("Istemci baglantiyi kapatti: {}", e.toString());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
        log.error("Yakalanmamis hata (traceId={}): {}", org.slf4j.MDC.get("requestId"), e.toString(), e);
        return json(500).body(withTrace(Map.of("code", "INTERNAL_ERROR", "message",
                i18n.error("INTERNAL_ERROR", defaultOf("INTERNAL_ERROR"), locale(), new Object[0]))));
    }

    private static boolean isClientAbort(Throwable t) {
        for (Throwable c = t; c != null; c = c.getCause()) {
            String n = c.getClass().getSimpleName();
            if (n.equals("ClientAbortException") || n.equals("AsyncRequestNotUsableException")) {
                return true;
            }
            if (c == c.getCause()) {
                break;
            }
        }
        return false;
    }

    private static String defaultOf(String code) {
        return switch (code) {
            case "NOT_FOUND" -> "Bulunamadı.";
            case "METHOD_NOT_ALLOWED" -> "Bu yöntem bu adreste desteklenmiyor.";
            case "NOT_ACCEPTABLE" -> "İstenen içerik türü sunulamıyor.";
            case "UNSUPPORTED_MEDIA_TYPE" -> "Desteklenmeyen içerik türü.";
            case "MALFORMED_REQUEST" -> "İstek biçimi geçersiz.";
            case "FORBIDDEN" -> "Bu işlem için yetkiniz yok.";
            case "UNAUTHORIZED" -> "Giriş gerekli.";
            case "INTERNAL_ERROR" -> "Beklenmeyen bir hata oluştu. Lütfen daha sonra tekrar deneyin.";
            default -> "İşlem tamamlanamadı.";
        };
    }

    private static Locale locale() {
        return LocaleContextHolder.getLocale();
    }

    private static ResponseEntity<Map<String, String>> body(HttpStatus status, String code, String message) {
        return json(status.value()).body(withTrace(Map.of("code", code, "message", message)));
    }

    /**
     * Ortak yanit basliklari: JSON (istemci Accept: text/html olsa bile icerik pazarligi hatasi olmasin),
     * Content-Language (mesaj dili) ve Vary: Accept-Language.
     */
    private static ResponseEntity.BodyBuilder json(int status) {
        return ResponseEntity.status(status).contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.CONTENT_LANGUAGE, locale().getLanguage())
                .header(HttpHeaders.VARY, HttpHeaders.ACCEPT_LANGUAGE);
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
