package edu.bingol.backend.academician;

import edu.bingol.backend.i18n.I18n;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * Akademisyen uclarinda konteyner/multipart boyut asimi (spring.servlet.multipart.max-file-size ya da max-request-size)
 * projenin JSON hata zarfiyla ve bu uca ozgu koda cevrilir: 413 {@code NOTICE_FILE_TOO_LARGE}. Genel isleyiciden once calisir.
 */
@RestControllerAdvice(assignableTypes = AcademicianController.class)
@Order(Ordered.HIGHEST_PRECEDENCE)
public class AcademicianUploadAdvice {

    private final I18n i18n;
    private final NoticeFileService files;

    public AcademicianUploadAdvice(I18n i18n, NoticeFileService files) {
        this.i18n = i18n;
        this.files = files;
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<Map<String, String>> tooLarge(MaxUploadSizeExceededException e) {
        long mb = Math.max(1, files.maxFileBytes() >> 20);
        String msg = i18n.error("NOTICE_FILE_TOO_LARGE", "Dosya en fazla " + mb + " MB olabilir.", LocaleContextHolder.getLocale(),
                new Object[] {String.valueOf(mb)});
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("code", "NOTICE_FILE_TOO_LARGE", "message", msg));
    }
}
