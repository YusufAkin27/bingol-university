package edu.bingol.backend.auth.twofactor;

import edu.bingol.backend.auth.twofactor.TwoFactorDtos.LoginChallengeResponse;
import edu.bingol.backend.common.ApiException;
import org.springframework.http.HttpStatus;

/**
 * Sifre dogru ama cihaz tanimiyor ve 2FA acik: token URETILMEZ. AuthController bunu yakalayip 202 +
 * {@link LoginChallengeResponse} doner. Yakalanmadan sizarsa (baska bir cagiran) genel hata isleyicisi 202 + hata
 * govdesi verir: yine token sizmaz (guvenli varsayilan). `AuthService.login` imzasi boylece degismeden kalir.
 */
public class TwoFactorRequiredException extends ApiException {

    private final transient LoginChallengeResponse challenge;

    public TwoFactorRequiredException(LoginChallengeResponse challenge) {
        super(HttpStatus.ACCEPTED, "TWO_FACTOR_REQUIRED", "İki faktörlü doğrulama kodu gerekli.");
        this.challenge = challenge;
    }

    public LoginChallengeResponse challenge() {
        return challenge;
    }
}
