package edu.bingol.backend.auth.dto;

/**
 * GET /api/auth/me. {@code hasPassword}: hesapta kullanilabilir bir parola var mi (yalniz OAuth ile acilan hesapta false).
 * Istemci, parola isteyen islemlerde (hesap silme, hesap baglama, 2FA kapatma) parola mi yoksa saglayici yeniden
 * dogrulamasi mi gosterecegini buradan bilir. Ek alan: eski istemciler yok sayar.
 */
public record UserView(Long id, String email, String displayName, boolean hasPassword) {
}
