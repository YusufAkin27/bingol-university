package edu.bingol.backend.common;

import org.springframework.http.HttpStatus;

/** 429 RATE_LIMITED (alt sinifta baska kod olabilir); `retryAfterSeconds` istemciye Retry-After basligi olarak doner. */
public class RateLimitedException extends ApiException {

    private final long retryAfterSeconds;

    public RateLimitedException(long retryAfterSeconds) {
        super(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "Cok fazla deneme. Lutfen daha sonra tekrar deneyin.");
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    /** Ozel hata kodlu 429 (ornegin ACCOUNT_TEMP_LOCKED); kod i18n'de `error.<KOD>` ile cevrilir. */
    protected RateLimitedException(String code, String message, long retryAfterSeconds) {
        super(HttpStatus.TOO_MANY_REQUESTS, code, message);
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    public long retryAfterSeconds() {
        return retryAfterSeconds;
    }
}
