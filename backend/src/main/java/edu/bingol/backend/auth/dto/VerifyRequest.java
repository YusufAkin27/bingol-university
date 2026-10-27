package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** `client` yalniz verify-email'de anlamlidir (mobile | web, varsayilan web): token'lar bu turde etiketlenir. */
public record VerifyRequest(@NotBlank @Email @Size(max = 254) String email,
                            @NotBlank @Size(min = 6, max = 6) String code,
                            @Pattern(regexp = "(?i)mobile|web") String client) {
}
