package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** `client`: mobile | web (opsiyonel, varsayilan web). mobile girisleri tek cihaz kuralina tabidir. */
public record LoginRequest(@NotBlank @Email @Size(max = 254) String email,
                           @NotBlank @Size(max = 72) String password,
                           @Pattern(regexp = "(?i)mobile|web") String client) {
}
