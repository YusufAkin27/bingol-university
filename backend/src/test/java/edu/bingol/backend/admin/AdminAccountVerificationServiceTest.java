package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.AccountCreator;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

class AdminAccountVerificationServiceTest {

    private static final String EMAIL = "226051015@bingol.edu.tr";

    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final AccountCreator accounts = mock(AccountCreator.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final SessionService sessions = mock(SessionService.class);
    private final AdminAccountVerificationService s =
            new AdminAccountVerificationService(pending, accounts, verification, users, sessions);

    private final Pending p = new Pending("h", "Ali", "tr");

    private static User user(long id, boolean verified) {
        User u = new User();
        u.setId(id);
        u.setEmail(EMAIL);
        u.setLanguage("tr");
        u.setEmailVerified(verified);
        return u;
    }

    @Test
    void verifyPendingCreatesAccountAndClearsState() {
        when(pending.find(EMAIL)).thenReturn(p);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(accounts.create(EMAIL, p)).thenReturn(user(5, true));

        User u = s.verifyPending("226051015", 1L);

        assertEquals(5L, u.getId());
        verify(pending).delete(EMAIL);
        verify(verification).clearVerify(EMAIL);
    }

    @Test
    void verifyPendingUnknownIs404() {
        ApiException e = assertThrows(ApiException.class, () -> s.verifyPending(EMAIL, 1L));
        assertEquals("PENDING_REGISTRATION_NOT_FOUND", e.code());
    }

    @Test
    void verifyPendingWhenAlreadyRegisteredIs409AndDropsPending() {
        when(pending.find(EMAIL)).thenReturn(p);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user(5, true)));

        ApiException e = assertThrows(ApiException.class, () -> s.verifyPending(EMAIL, 1L));

        assertEquals("EMAIL_ALREADY_REGISTERED", e.code());
        verify(pending).delete(EMAIL);
        verify(accounts, never()).create(any(), any());
    }

    @Test
    void verifyPendingUniqueViolationIs409() {
        when(pending.find(EMAIL)).thenReturn(p);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(accounts.create(EMAIL, p)).thenThrow(new DataIntegrityViolationException("dup"));

        ApiException e = assertThrows(ApiException.class, () -> s.verifyPending(EMAIL, 1L));

        assertEquals("EMAIL_ALREADY_REGISTERED", e.code());
        verify(pending).delete(EMAIL);
    }

    @Test
    void resendIssuesCodeAndPropagatesCooldown() {
        when(pending.find(EMAIL)).thenReturn(p);
        s.resendPending("226051015");
        verify(verification).issue(EMAIL, Lang.of("tr"));
        verify(pending).markResend(EMAIL);

        doThrow(new ApiException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN", "x"))
                .when(verification).issue(eq(EMAIL), any());
        ApiException e = assertThrows(ApiException.class, () -> s.resendPending(EMAIL));
        assertEquals("RESEND_COOLDOWN", e.code());
    }

    @Test
    void resendUnknownIs404() {
        ApiException e = assertThrows(ApiException.class, () -> s.resendPending(EMAIL));
        assertEquals("PENDING_REGISTRATION_NOT_FOUND", e.code());
    }

    @Test
    void verifyUserFlipsFlagAndIsIdempotent() {
        User u = user(7, false);
        when(users.findById(7L)).thenReturn(Optional.of(u));
        when(users.save(u)).thenReturn(u);

        assertTrue(s.verifyUser(7L, 1L).isEmailVerified());
        s.verifyUser(7L, 1L);

        verify(users).save(u); // ikinci cagri kaydetmez
    }

    @Test
    void sendResetRequiresVerifiedUser() {
        when(users.findById(7L)).thenReturn(Optional.of(user(7, false)));
        ApiException e = assertThrows(ApiException.class, () -> s.sendReset(7L));
        assertEquals("USER_NOT_VERIFIED", e.code());

        when(users.findById(8L)).thenReturn(Optional.of(user(8, true)));
        s.sendReset(8L);
        verify(verification).issueReset(EMAIL, Lang.of("tr"));
    }

    @Test
    void revokeSessionsDelegatesAndUnknownIs404() {
        when(users.findById(7L)).thenReturn(Optional.of(user(7, true)));
        s.revokeSessions(7L);
        verify(sessions).revokeAll(7L);

        ApiException e = assertThrows(ApiException.class, () -> s.revokeSessions(99L));
        assertEquals("USER_NOT_FOUND", e.code());
    }
}
