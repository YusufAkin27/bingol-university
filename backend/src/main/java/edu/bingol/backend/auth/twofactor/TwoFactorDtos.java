package edu.bingol.backend.auth.twofactor;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** 2FA uc sekilleri (docs/TWO_FACTOR_API.md). */
public final class TwoFactorDtos {

    private TwoFactorDtos() {}

    /** 202 giris cevabi: token YOK; kod e-postaya gitti. */
    public record LoginChallengeResponse(boolean twoFactorRequired, String challengeToken, String emailHint,
                                         long expiresInSeconds) {}

    public record TwoFactorLoginRequest(@NotBlank @Size(max = 200) String challengeToken,
                                        @NotBlank @Size(max = 16) String code, Boolean trustDevice) {
        /** Varsayilan true. */
        public boolean trust() {
            return trustDevice == null || trustDevice;
        }
    }

    public record ChallengeRequest(@NotBlank @Size(max = 200) String challengeToken) {}

    public record ResendResponse(long expiresInSeconds) {}

    public record CodeRequest(@NotBlank @Size(max = 16) String code) {}

    public record DisableRequest(@NotBlank @Size(max = 200) String password) {}

    public record StatusResponse(boolean enabled, long trustedDeviceCount, boolean currentDeviceTrusted) {}

    public record EnabledResponse(boolean enabled) {}

    /** Ham cihaz kimligi/ozeti DONMEZ; yalnizca etiket ve zamanlar. */
    public record DeviceView(Long id, String label, String createdAt, String lastUsedAt, boolean current) {}
}
