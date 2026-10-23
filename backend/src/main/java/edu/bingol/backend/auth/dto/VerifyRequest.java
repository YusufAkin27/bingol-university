package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record VerifyRequest(@NotBlank @Email @Size(max = 254) String email,
                            @NotBlank @Size(min = 6, max = 6) String code) {
}
