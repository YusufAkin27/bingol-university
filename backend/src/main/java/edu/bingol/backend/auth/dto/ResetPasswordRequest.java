package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** resetToken: verify-reset-code cevabindaki tek kullanimlik anahtar. */
public record ResetPasswordRequest(@NotBlank @Email @Size(max = 254) String email,
                                   @NotBlank @Size(max = 100) String resetToken,
                                   @NotBlank @Size(min = 8, max = 72) String newPassword) {
}
