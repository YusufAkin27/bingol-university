package edu.bingol.backend.auth.realemail;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Gercek e-posta akisi istek/yanit sekilleri (bkz. docs/changes/auth.md "Gercek e-posta (role) dogrulamasi"). */
public final class RealEmailDtos {

    private RealEmailDtos() {
    }

    /**
     * `email`: yeni (gercek, aktif) adres. Yeniden dogrulama YALNIZ role OLMAYAN hesapta istenir: parolali hesapta
     * `password`; parolasiz (Google) hesapta bagli saglayicinin taze token'i (`reauth*`). Role (Apple gizli adres)
     * hesabinda hicbiri gerekmez (oturum yeterli: hesabin tek ve kullanilamaz adresi duzeltiliyor).
     */
    public record StartRequest(@NotBlank @Size(max = 254) String email,
                               @Size(max = 72) String password,
                               @Pattern(regexp = "(?i)google|apple") String reauthProvider,
                               @Size(max = 8192) String reauthToken,
                               @Size(max = 256) String reauthNonce) {
    }

    /** Kod gonderildi: `emailMasked` yalniz ekranda gostermek icin (a***@gmail.com). */
    public record StartResponse(boolean sent, String emailMasked, int expiresInSeconds, int resendInSeconds) {
    }

    public record VerifyRequest(@NotBlank @Pattern(regexp = "\\d{6}") String code) {
    }

    /** Dogrulama sonucu: hesabin yeni (tek) e-postasi + guncel durum bayraklari. */
    public record VerifyResponse(String email, boolean emailVerified, boolean emailNeedsReal,
                                 boolean realEmailRequired) {
    }
}
