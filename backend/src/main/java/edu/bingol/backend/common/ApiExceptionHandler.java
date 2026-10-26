package edu.bingol.backend.common;

import edu.bingol.backend.i18n.I18n;
import java.util.Locale;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
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
        return body(e.status(), e.code(), i18n.error(e.code(), e.getMessage(), locale(), e.args()));
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

    private static Locale locale() {
        return LocaleContextHolder.getLocale();
    }

    private static ResponseEntity<Map<String, String>> body(HttpStatus status, String code, String message) {
        return ResponseEntity.status(status).body(Map.of("code", code, "message", message));
    }
}
