package edu.bingol.backend.auth.twofactor;

import com.fasterxml.jackson.annotation.JsonInclude;
import edu.bingol.backend.auth.dto.TokenResponse;
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
        /** Varsayilan FALSE: alan yoksa cihaz guvenilir yapilmaz (istemci "guven" kutusunu acikca gonderir). */
        public boolean trust() {
            return Boolean.TRUE.equals(trustDevice);
        }
    }

    public record ChallengeRequest(@NotBlank @Size(max = 200) String challengeToken) {}

    public record ResendResponse(long expiresInSeconds) {}

    /** {@code closeOtherSessions} (istege bagli, varsayilan false): true ise tum oturumlar kapanir, yanitta yeni cift gelir. */
    public record CodeRequest(@NotBlank @Size(max = 16) String code, Boolean closeOtherSessions) {
        public CodeRequest(String code) {
            this(code, null);
        }

        public boolean closeOthers() {
            return Boolean.TRUE.equals(closeOtherSessions);
        }
    }

    public record DisableRequest(@NotBlank @Size(max = 200) String password, Boolean closeOtherSessions) {
        public DisableRequest(String password) {
            this(password, null);
        }

        public boolean closeOthers() {
            return Boolean.TRUE.equals(closeOtherSessions);
        }
    }

    public record StatusResponse(boolean enabled, long trustedDeviceCount, boolean currentDeviceTrusted) {}

    /** {@code session}: yalniz {@code closeOtherSessions=true} istendiyse dolu (bu cihaz icin yeni jeton cifti). */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record EnabledResponse(boolean enabled, TokenResponse session) {
        public EnabledResponse(boolean enabled) {
            this(enabled, null);
        }
    }

    /** Ham cihaz kimligi/ozeti DONMEZ; yalnizca etiket ve zamanlar. */
    public record DeviceView(Long id, String label, String createdAt, String lastUsedAt, boolean current) {}
}
