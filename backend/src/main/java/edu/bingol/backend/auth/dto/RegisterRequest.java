package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * acceptTerms: kullanim kosullari, gizlilik, KVKK aydinlatma ve topluluk kurallarinin kabulu (zorunlu).
 * language: tr | en | ar (opsiyonel; verilmezse Accept-Language, o da yoksa tr) — bildirim ve e-posta dili.
 * faculty/department/grade: opsiyonel; verilirse akademik katalogla dogrulanir (ACADEMIC_INVALID).
 */
public record RegisterRequest(@NotBlank @Size(max = 254) String email,
                              @NotBlank @Size(min = 8, max = 72) String password,
                              @NotBlank @Size(max = 80) String displayName,
                              @AssertTrue(message = "{error.TERMS_NOT_ACCEPTED}") boolean acceptTerms,
                              @Pattern(regexp = "tr|en|ar") String language,
                              @Size(max = 120) String faculty,
                              @Size(max = 120) String department,
                              @Size(max = 8) String grade) {
}
