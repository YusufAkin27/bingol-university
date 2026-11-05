package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Kimlik dogrulamali e-posta dogrulama uclari (kota asiminda ertelenmis hesaplar; bkz. docs/changes/auth.md). */
public final class VerificationDtos {

    private VerificationDtos() {
    }

    public record VerifyCodeRequest(@NotBlank @Size(min = 6, max = 6) String code) {
    }

    public record StatusResponse(boolean emailVerified, boolean verificationDeferred, String email) {
    }

    public record VerifiedResponse(boolean emailVerified, boolean verificationDeferred) {
    }
}
