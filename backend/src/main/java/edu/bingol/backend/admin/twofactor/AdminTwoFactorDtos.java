package edu.bingol.backend.admin.twofactor;

import java.util.List;

/** Yonetici 2FA uc sekilleri (docs/ADMIN_API.md "Iki faktorlu dogrulama", docs/TWO_FACTOR_API.md). */
public final class AdminTwoFactorDtos {

    private AdminTwoFactorDtos() {}

    /** `enabledPercent`: aktif kullanicilar icindeki oran (tek ondalik). */
    public record Summary(long enabledCount, long totalActiveUsers, double enabledPercent, long enabledLast7Days,
                          long trustedDeviceTotal) {}

    /** `email`: users.pii olmayan profiller icin maskeli. `lastLoginAt`: son guvenilen/dogrulanan giris, yoksa son gorulme. */
    public record UserRow(Long userId, String displayName, String email, String role, String enabledAt,
                          long trustedDeviceCount, String lastLoginAt) {}

    /** Spring Data benzeri sayfa govdesi. */
    public record UserPage(List<UserRow> content, long totalElements, int totalPages, int number, int size) {}

    /** `reason` zorunlu (>= 5 karakter; AdminGuardPolicy ayrica denetler); govdeden AuditContext'e de okunur. */
    public record DisableRequest(String reason) {}
}
