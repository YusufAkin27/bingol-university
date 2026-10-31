package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** resetToken: verify-reset-code cevabindaki tek kullanimlik anahtar. */
public record ResetPasswordRequest(@NotBlank @Size(max = 254) String email,
                                   @NotBlank @Size(max = 100) String resetToken,
                                   @NotBlank @Size(max = 72) String newPassword) {
}
