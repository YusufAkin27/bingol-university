package edu.bingol.backend.auth.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Jeton cifti. `emailVerified`/`verificationDeferred` YALNIZ kota asiminda ertelenmis dogrulama hesabinda vardir
 * (false/true); normal hesapta null olup JSON'a yazilmaz (geriye uyumlu).
 */
public record TokenResponse(String accessToken, String refreshToken, long expiresInSeconds, String tokenType,
                            @JsonInclude(JsonInclude.Include.NON_NULL) Boolean emailVerified,
                            @JsonInclude(JsonInclude.Include.NON_NULL) Boolean verificationDeferred) {

    public TokenResponse(String accessToken, String refreshToken, long expiresInSeconds, String tokenType) {
        this(accessToken, refreshToken, expiresInSeconds, tokenType, null, null);
    }

    /** Ertelenmis dogrulama hesabi isareti: emailVerified=false, verificationDeferred=true. */
    public TokenResponse asDeferred() {
        return new TokenResponse(accessToken, refreshToken, expiresInSeconds, tokenType, false, true);
    }
}
