package edu.bingol.backend.auth;

import edu.bingol.backend.common.ApiException;
import org.springframework.http.HttpStatus;

/**
 * 409 REFRESH_IN_PROGRESS: ayni refresh token ile es zamanli ikinci istek geldi, yeni cift henuz yazilmadi.
 * Oturum bitmedi; istemci `Retry-After` (1 sn) sonra AYNI token'la yeniden dener ve ayni cifti alir
 * (bkz. AuthController.refresh, RefreshTokenService.replayRotation).
 */
public class RefreshInProgressException extends ApiException {

    public RefreshInProgressException() {
        super(HttpStatus.CONFLICT, "REFRESH_IN_PROGRESS", "Oturum yenileme sürüyor, kısa süre sonra tekrar deneyin.");
    }
}
