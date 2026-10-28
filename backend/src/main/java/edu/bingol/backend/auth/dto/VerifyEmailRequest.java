package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Kayit e-postasi dogrulama. `client` mobile | web (varsayilan web). `password`: kayit adiminda girilen parola
 * (parola kaniti; bekleyen kaydin ozetiyle karsilastirilir). Eski istemciler icin
 * `app.auth.verify-requires-password=false` ile bos birakilabilir.
 */
public record VerifyEmailRequest(@NotBlank @Size(max = 254) String email,
                                 @NotBlank @Size(min = 6, max = 6) String code,
                                 @Pattern(regexp = "(?i)mobile|web") String client,
                                 @Size(max = 72) String password) {
}
