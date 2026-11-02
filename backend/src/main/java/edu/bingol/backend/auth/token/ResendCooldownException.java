package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.RateLimitedException;

/**
 * 429 RESEND_COOLDOWN: dogrulama kodu yeniden isteme bekleme suresi dolmadi. `Retry-After` basligi ve govdedeki
 * `retryAfterSeconds` kalan sureyi saniye olarak verir (istemci geri sayimi buradan baslatir).
 */
public class ResendCooldownException extends RateLimitedException {

    public static final String CODE = "RESEND_COOLDOWN";

    public ResendCooldownException(long remainingSeconds) {
        super(remainingSeconds, CODE, "Yeni kod istemek için lütfen bekleyin.", String.valueOf(Math.max(1, remainingSeconds)));
    }
}
