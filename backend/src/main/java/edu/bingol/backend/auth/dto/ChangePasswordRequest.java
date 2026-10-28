package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Oturum acik kullanicinin sifre degisimi; yeni sifre kurali kayit/sifirlama ile ayni (8-72). */
public record ChangePasswordRequest(@NotBlank @Size(max = 72) String currentPassword,
                                    @NotBlank @Size(min = 8, max = 72) String newPassword) {
}
