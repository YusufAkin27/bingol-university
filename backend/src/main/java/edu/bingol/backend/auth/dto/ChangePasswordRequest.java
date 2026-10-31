package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Oturum acik kullanicinin sifre degisimi; yeni sifre kurali kayit/sifirlama ile ayni (PasswordPolicy; en az uzunluk serviste: PASSWORD_TOO_WEAK). */
public record ChangePasswordRequest(@NotBlank @Size(max = 72) String currentPassword,
                                    @NotBlank @Size(max = 72) String newPassword) {
}
