package edu.bingol.backend.common;

import org.springframework.http.HttpStatus;

/** 503 REDIS_UNAVAILABLE; `retryAfterSeconds` Retry-After basligi olarak doner (bkz. {@link RedisBreaker}). */
public class RedisUnavailableException extends ApiException {

    private final long retryAfterSeconds;

    public RedisUnavailableException(long retryAfterSeconds) {
        super(HttpStatus.SERVICE_UNAVAILABLE, "REDIS_UNAVAILABLE",
                "Sistem geçici olarak kullanılamıyor. Lütfen birkaç saniye sonra tekrar deneyin.");
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    public long retryAfterSeconds() {
        return retryAfterSeconds;
    }
}
