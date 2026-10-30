package edu.bingol.backend.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Cikis. `fcmToken` (istege bagli): bu cihazin push kaydi sunucuda da silinir; erisim jetonu suresi dolmus olsa bile
 * (DELETE /api/devices/{token} 401 verirdi) cikis yapan kullanicinin bildirimi bu telefona gitmeye devam etmez.
 */
public record LogoutRequest(@NotBlank @Size(max = 200) String refreshToken, @Size(max = 500) String fcmToken) {
}
