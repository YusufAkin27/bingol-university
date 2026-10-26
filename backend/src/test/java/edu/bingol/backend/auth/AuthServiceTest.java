package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalService;
import java.util.List;
import java.util.Optional;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class AuthServiceTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final UserRepository users = mock(UserRepository.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final SessionService sessions = mock(SessionService.class);
    private final LegalService legal = mock(LegalService.class);
    private final JwtService jwt = mock(JwtService.class);
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(4), jwt, refresh,
            verification, new AdminProperties(List.of()), legal, pending, sessions);

    @ParameterizedTest
    @ValueSource(strings = {"a@gmail.com", "a@bingol.edu.tr.evil.com", "a@evilbingol.edu.tr", "a@bingol.edu.com"})
    void rejectsNonUniversityEmails(String email) {
        ApiException e = assertThrows(ApiException.class, () -> auth.register(email, "Sifre1234", "Ali", Lang.TR));

        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification, pending);
    }

    @Test
    void normalizesEmail() {
        assertEquals("ali.veli@bingol.edu.tr", AuthService.normalizeEmail("  Ali.Veli@Bingol.EDU.tr "));
    }

    @Test
    void registerKeepsDataInRedisAndNeverTouchesUserTable() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        auth.register(" Ali@bingol.edu.tr ", "Sifre1234", " Ali ", Lang.TR);

        verify(verification).issue(EMAIL, Lang.TR);
        verify(pending).save(eq(EMAIL), any(Pending.class));
        verify(users, never()).save(any());
    }

    @Test
    void registerDoesNotOverwriteExistingUnverifiedAccount() {
        User unverified = new User();
        unverified.setEmail(EMAIL);
        unverified.setPasswordHash("old-hash");
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(unverified));

        auth.register(EMAIL, "Sifre1234", "Mallory", Lang.TR);

        assertEquals("old-hash", unverified.getPasswordHash());
        verify(users, never()).save(any());
    }

    @Test
    void registerRejectsVerifiedEmail() {
        User verified = new User();
        verified.setEmailVerified(true);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verified));

        ApiException e = assertThrows(ApiException.class, () -> auth.register(EMAIL, "Sifre1234", "Ali", Lang.TR));

        assertEquals("EMAIL_ALREADY_REGISTERED", e.code());
        verifyNoInteractions(verification);
    }

    @Test
    void resendCodeWithoutPendingRegistrationDoesNothing() {
        auth.resendCode(EMAIL);

        verifyNoInteractions(verification);
    }

    @Test
    void resendCodeSwallowsCooldownAndMailFailures() {
        when(pending.find(EMAIL)).thenReturn(new Pending("h", "Ali", "tr"));
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "x"))
                .when(verification).issue(anyString(), any());

        auth.resendCode(EMAIL);

        doThrow(new IllegalStateException("smtp")).when(verification).issue(anyString(), any());
        auth.resendCode(EMAIL);
    }

    @Test
    void verifyEmailWithoutPendingRegistrationIsGenericInvalidCode() {
        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "123456"));

        assertEquals("INVALID_CODE", e.code());
        verifyNoInteractions(verification);
    }

    @Test
    void verifyEmailWithWrongCodeCreatesNoAccount() {
        when(pending.find(EMAIL)).thenReturn(new Pending("h", "Ali", "tr"));
        when(verification.verify(EMAIL, "000000")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyEmail(EMAIL, "000000"));

        assertEquals("INVALID_CODE", e.code());
        verify(users, never()).save(any());
    }

    @Test
    void verifyEmailCreatesAccountFromFirstRegistrationData() {
        when(pending.find(EMAIL)).thenReturn(new Pending("hash-1", "Ali", "en"));
        when(verification.verify(EMAIL, "123456")).thenReturn(true);
        when(users.save(any(User.class))).thenAnswer(i -> i.getArgument(0));

        auth.verifyEmail(EMAIL, " 123456 ");

        org.mockito.ArgumentCaptor<User> saved = org.mockito.ArgumentCaptor.forClass(User.class);
        verify(users).save(saved.capture());
        assertEquals("hash-1", saved.getValue().getPasswordHash());
        assertEquals("Ali", saved.getValue().getDisplayName());
        assertEquals("en", saved.getValue().getLanguage());
        assertTrue(saved.getValue().isEmailVerified());
        verify(pending).delete(EMAIL);
    }

    @Test
    void loginForUnknownUserIsGenericInvalidCredentials() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, "Sifre1234"));

        assertEquals("INVALID_CREDENTIALS", e.code());
    }

    @Test
    void logoutAllRevokesEverySession() {
        auth.logoutAll(7L);

        verify(sessions).revokeAll(7L);
    }

    private static User verifiedUser() {
        User u = new User();
        u.setId(7L);
        u.setEmail(EMAIL);
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
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "bekleyin"))
                .when(verification).issueReset(any(), any());

        auth.forgotPassword(EMAIL);
    }

    @Test
    void verifyResetCodeRejectsWrongCode() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        when(verification.verifyReset(EMAIL, "111111")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.verifyResetCode(EMAIL, "111111"));

        assertEquals("INVALID_CODE", e.code());
        verify(verification, never()).issueResetToken(any());
    }

    @Test
    void verifyResetCodeReturnsToken() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        when(verification.verifyReset(EMAIL, "123456")).thenReturn(true);
        when(verification.issueResetToken(EMAIL)).thenReturn("tok");

        assertEquals("tok", auth.verifyResetCode("Ali@bingol.edu.tr", "123456"));
    }

    @Test
    void resetPasswordRejectsBadToken() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(verifiedUser()));
        when(verification.consumeResetToken(EMAIL, "kotu")).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> auth.resetPassword(EMAIL, "kotu", "YeniSifre123"));

        assertEquals("INVALID_CODE", e.code());
        verify(users, never()).save(any());
        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void resetPasswordStoresNewHashAndClosesAllSessions() {
        User u = verifiedUser();
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(u));
        when(verification.consumeResetToken(EMAIL, "tok")).thenReturn(true);

        auth.resetPassword(" Ali@bingol.edu.tr ", "tok", "YeniSifre123");

        org.junit.jupiter.api.Assertions.assertNotEquals("eski", u.getPasswordHash());
        verify(users).save(u);
        verify(sessions).revokeAll(7L);
    }
}
