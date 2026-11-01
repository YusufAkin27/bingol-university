package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** FIX-P02/A01#15: bekleyen kayit yokken de bcrypt maliyeti odenir (yanit suresinden varlik sezilmez). */
class VerifyEmailTimingTest {

    private static final String EMAIL = "ali@bingol.edu.tr";
    private static final String PW = "Gizli-parola-123";

    @Test
    void verifyEmailWithoutPendingRegistrationStillSpendsOneBcryptComparison() {
        BCryptPasswordEncoder encoder = spy(new BCryptPasswordEncoder(4));
        PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
        UserRepository users = mock(UserRepository.class);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(pending.find(EMAIL)).thenReturn(null);
        AuthService auth = new AuthService(users, encoder, mock(JwtService.class), mock(RefreshTokenService.class),
                mock(VerificationService.class), new AdminProperties(List.of()), mock(AccountCreator.class), pending,
                mock(SessionService.class), new CatalogService());

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "123456", null, null, PW));

        assertEquals("INVALID_CODE", e.code());
        verify(encoder, times(1)).matches(eq(PW), anyString());
    }
}
