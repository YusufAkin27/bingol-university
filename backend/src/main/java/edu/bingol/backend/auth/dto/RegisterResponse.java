package edu.bingol.backend.auth.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Kayit yaniti. Normal akis: yalniz `message` (202). Kota asiminda ertelenmis dogrulama (201): `message` + jeton cifti +
 * `emailVerified=false` + `verificationDeferred=true`. Null alanlar JSON'a yazilmaz.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record RegisterResponse(String message, Boolean emailVerified, Boolean verificationDeferred,
                               String accessToken, String refreshToken, Long expiresInSeconds, String tokenType) {

    public static RegisterResponse sent(String message) {
        return new RegisterResponse(message, null, null, null, null, null, null);
    }

    public static RegisterResponse deferred(String message, TokenResponse t) {
        return new RegisterResponse(message, false, true, t.accessToken(), t.refreshToken(), t.expiresInSeconds(),
                t.tokenType());
    }
}
