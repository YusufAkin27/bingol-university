package edu.bingol.backend.auth.oauth;

import com.fasterxml.jackson.annotation.JsonProperty;
import edu.bingol.backend.auth.dto.TokenResponse;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Google/Apple giris ve baglama istek/yanit sekilleri (bkz. docs/changes/auth.md "Google / Apple ile giris"). */
public final class OAuthDtos {

    private OAuthDtos() {
    }

    /** `client`: mobile (varsayilan; tek cihaz kuralina tabi) | web. `deviceName` bilgi amaclidir, saklanmaz. */
    public record GoogleLoginRequest(@NotBlank @Size(max = 8192) String idToken,
                                     @Size(max = 80) String deviceName,
                                     @Pattern(regexp = "(?i)mobile|web") String client) {
    }

    /**
     * `nonce` HAM degerdir (Apple'a SHA-256(ham) hex verilmistir). `firstName`/`lastName` Apple'in YALNIZ ilk
     * yetkilendirmede verdigi ad bilgisidir; istemci gonderirse yeni hesapta on dolduruntu olarak saklanir.
     */
    public record AppleLoginRequest(@NotBlank @Size(max = 8192) String identityToken,
                                    @NotBlank @Size(max = 256) String nonce,
                                    @Size(max = 80) String firstName, @Size(max = 80) String lastName,
                                    @Size(max = 80) String deviceName,
                                    @Pattern(regexp = "(?i)mobile|web") String client) {
    }

    /**
     * Jeton cifti + profil durumu. `emailVerified`/`verificationDeferred` OAuth'ta hic gelmez (hesap dogrulanmis acilir).
     * `isNewUser`: bu istekte hesap acildi mi; `profileCompleted=false` iken sunucu yazma uclarini kapatir
     * (403 PROFILE_INCOMPLETE) ve onboarding (PUT /api/users/me/onboarding) beklenir.
     * `emailNeedsReal`: hesap e-postasi Apple gizli (role) adresi: uygulama "gercek e-posta" adimini gosterir
     * (POST /api/users/me/email/start + /verify). `realEmailRequired`: yeni role hesapta ZORUNLU kapi (gercek adres
     * dogrulanana kadar yazma uclari 403 REAL_EMAIL_REQUIRED); mevcut role hesaplarda false (yumusak adim).
     */
    public record OAuthLoginResponse(String accessToken, String refreshToken, long expiresInSeconds, String tokenType,
                                     boolean profileCompleted,
                                     @JsonProperty("isNewUser") boolean isNewUser,
                                     boolean emailNeedsReal, boolean realEmailRequired) {
        public static OAuthLoginResponse of(TokenResponse t, boolean profileCompleted, boolean isNewUser) {
            return new OAuthLoginResponse(t.accessToken(), t.refreshToken(), t.expiresInSeconds(), t.tokenType(),
                    profileCompleted, isNewUser, false, false);
        }

        public static OAuthLoginResponse of(TokenResponse t, edu.bingol.backend.user.User user, boolean isNewUser) {
            return new OAuthLoginResponse(t.accessToken(), t.refreshToken(), t.expiresInSeconds(), t.tokenType(),
                    user.isProfileCompleted(), isNewUser, user.isEmailRelay(),
                    user.isEmailRelay() && user.isRealEmailRequired());
        }
    }

    /**
     * Baglama: `token` saglayici token'i (Google idToken / Apple identityToken + `nonce`). Yeniden dogrulama: parolasi
     * olan hesapta `password`; parolasiz (yalniz OAuth) hesapta bagli bir saglayicinin taze token'i (`reauth*`).
     */
    public record LinkRequest(@NotBlank @Pattern(regexp = "(?i)google|apple") String provider,
                              @NotBlank @Size(max = 8192) String token,
                              @Size(max = 256) String nonce,
                              @Size(max = 72) String password,
                              @Pattern(regexp = "(?i)google|apple") String reauthProvider,
                              @Size(max = 8192) String reauthToken,
                              @Size(max = 256) String reauthNonce) {
    }

    public record LinkResponse(boolean linked) {
    }
}
