package edu.bingol.backend.common;

import org.springframework.http.HttpStatus;

/** 429 RATE_LIMITED; `retryAfterSeconds` istemciye Retry-After basligi olarak doner. */
public class RateLimitedException extends ApiException {

    private final long retryAfterSeconds;

    public RateLimitedException(long retryAfterSeconds) {
        super(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "Cok fazla deneme. Lutfen daha sonra tekrar deneyin.");
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    /** Alt siniflar icin: ozel hata kodu/metni (ornegin RESEND_COOLDOWN) ayni Retry-After davranisiyla. */
    protected RateLimitedException(long retryAfterSeconds, String code, String message, Object... args) {
        super(HttpStatus.TOO_MANY_REQUESTS, code, message, args);
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    public long retryAfterSeconds() {
        return retryAfterSeconds;
    }
}
