package edu.bingol.backend.common.web;

import java.io.IOException;

/** Akış okunurken gövde sınırı aşıldı ({@link RequestBodyLimitFilter}); ApiExceptionHandler 413'e çevirir. */
public class RequestBodyTooLargeException extends IOException {

    private final long limit;

    public RequestBodyTooLargeException(long limit) {
        super("Istek govdesi siniri asildi: " + limit);
        this.limit = limit;
    }

    public long limit() {
        return limit;
    }

    /** Hata zincirinde bu istisna var mı (Jackson/Spring sarmalayıcıları arasından). */
    public static boolean in(Throwable t) {
        int depth = 0;
        while (t != null && depth++ < 10) {
            if (t instanceof RequestBodyTooLargeException) {
                return true;
            }
            t = t.getCause();
        }
        return false;
    }
}
