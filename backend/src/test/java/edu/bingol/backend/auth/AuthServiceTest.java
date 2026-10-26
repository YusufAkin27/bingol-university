package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verifyNoInteractions;

import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalService;
import java.util.List;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class AuthServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(),
            mock(JwtService.class), mock(RefreshTokenService.class), verification, new AdminProperties(List.of()),
            mock(LegalService.class));

    @ParameterizedTest
    @ValueSource(strings = {"a@gmail.com", "a@bingol.edu.tr.evil.com", "a@evilbingol.edu.tr", "a@bingol.edu.com"})
    void rejectsNonUniversityEmails(String email) {
        ApiException e = assertThrows(ApiException.class, () -> auth.register(email, "Sifre1234", "Ali", Lang.TR));

        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification);
    }

    @Test
    void normalizesEmail() {
        assertEquals("ali.veli@bingol.edu.tr", AuthService.normalizeEmail("  Ali.Veli@Bingol.EDU.tr "));
    }

    private static User verifiedUser() {
        User u = new User();
        u.setEmail("ali@bingol.edu.tr");
        u.setEmailVerified(true);
        u.setPasswordHash("eski");
        u.setLanguage("tr");
        return u;
    }

    @Test
    void forgotPasswordIsSilentForUnknownAccount() {
        when(users.findByEmail("yok@bingol.edu.tr")).thenReturn(Optional.empty());

        auth.forgotPassword("yok@bingol.edu.tr");

        verify(verification, never()).issueReset(any(), any());
    }

    @Test
    void forgotPasswordSwallowsCooldownSoExistenceDoesNotLeak() {
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.of(verifiedUser()));
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "bekleyin"))
                .when(verification).issueReset(any(), any());

        auth.forgotPassword("ali@bingol.edu.tr");
    }

    @Test
    void verifyResetCodeRejectsWrongCode() {
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.of(verifiedUser()));
        when(verification.verifyReset("ali@bingol.edu.tr", "111111")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyResetCode("ali@bingol.edu.tr", "111111"));

        assertEquals("INVALID_CODE", e.code());
        verify(verification, never()).issueResetToken(any());
    }

    @Test
    void verifyResetCodeReturnsToken() {
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.of(verifiedUser()));
        when(verification.verifyReset("ali@bingol.edu.tr", "123456")).thenReturn(true);
        when(verification.issueResetToken("ali@bingol.edu.tr")).thenReturn("tok");

        assertEquals("tok", auth.verifyResetCode("Ali@bingol.edu.tr", "123456"));
    }

    @Test
    void resetPasswordRejectsBadToken() {
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.of(verifiedUser()));
        when(verification.consumeResetToken("ali@bingol.edu.tr", "kotu")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class,
                () -> auth.resetPassword("ali@bingol.edu.tr", "kotu", "YeniSifre123"));

        assertEquals("INVALID_CODE", e.code());
        verify(users, never()).save(any());
    }

    @Test
    void resetPasswordStoresNewHash() {
        User u = verifiedUser();
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.of(u));
        when(verification.consumeResetToken("ali@bingol.edu.tr", "tok")).thenReturn(true);

        auth.resetPassword(" Ali@bingol.edu.tr ", "tok", "YeniSifre123");

        assertNotEquals("eski", u.getPasswordHash());
        verify(users).save(u);
    }
}
