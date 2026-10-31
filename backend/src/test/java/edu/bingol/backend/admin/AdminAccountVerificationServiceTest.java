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
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

class AdminAccountVerificationServiceTest {

    private static final String EMAIL = "226051015@bingol.edu.tr";

    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final AccountCreator accounts = mock(AccountCreator.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final SessionService sessions = mock(SessionService.class);
    private final AdminAccountVerificationService s =
            new AdminAccountVerificationService(pending, accounts, verification, users, sessions,
                    new edu.bingol.backend.config.AdminProperties(java.util.List.of("boss@bingol.edu.tr")));

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
        when(accounts.create(EMAIL, p, false)).thenReturn(user(5, true));

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
        verify(accounts, never()).create(any(), any(), org.mockito.ArgumentMatchers.anyBoolean());
    }

    @Test
    void verifyPendingUniqueViolationIs409() {
        when(pending.find(EMAIL)).thenReturn(p);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(accounts.create(EMAIL, p, false)).thenThrow(new DataIntegrityViolationException("dup"));

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

    /** T-011: ADMIN_EMAILS adresi kodsuz dogrulanamaz (sabit FULL yonetici olurdu). */
    @Test
    void adminEmailCannotBeVerifiedWithoutCode() {
        String boss = "boss@bingol.edu.tr";
        when(pending.find(boss)).thenReturn(p);
        ApiException e = assertThrows(ApiException.class, () -> s.verifyPending(boss, 1L));
        assertEquals("VERIFY_ADMIN_EMAIL_FORBIDDEN", e.code());
        assertEquals(409, e.status().value());
        verify(accounts, never()).create(any(), any(), org.mockito.ArgumentMatchers.anyBoolean());
        verify(pending, never()).delete(any());

        User u = user(9, false);
        u.setEmail(boss);
        when(users.findById(9L)).thenReturn(Optional.of(u));
        ApiException e2 = assertThrows(ApiException.class, () -> s.verifyUser(9L, 1L));
        assertEquals("VERIFY_ADMIN_EMAIL_FORBIDDEN", e2.code());
        verify(users, never()).save(any());
    }

    /** T-014: MODERATOR (FULL olmayan) yonetici hedefte sifirlama/oturum kapatma/dogrulama yapamaz. */
    @Test
    void nonFullAdminCannotTouchAdminTargets() {
        User target = user(11, true);
        target.setRole(edu.bingol.backend.user.Role.ADMIN);
        when(users.findById(11L)).thenReturn(Optional.of(target));
        MockHttpServletRequest req = new MockHttpServletRequest();
        edu.bingol.backend.admin.rbac.AdminPermissionContext.put(req,
                new edu.bingol.backend.admin.rbac.AdminPermissionContext(
                        edu.bingol.backend.admin.rbac.AdminProfile.MODERATOR, false));
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(req));
        try {
            assertEquals("ADMIN_TARGET_FORBIDDEN", assertThrows(ApiException.class, () -> s.sendReset(11L)).code());
            assertEquals("ADMIN_TARGET_FORBIDDEN", assertThrows(ApiException.class, () -> s.revokeSessions(11L)).code());
            assertEquals("ADMIN_TARGET_FORBIDDEN", assertThrows(ApiException.class, () -> s.verifyUser(11L, 1L)).code());
            verify(sessions, never()).revokeAll(any());
            // FULL yonetici ayni hedefe mudahale eder
            edu.bingol.backend.admin.rbac.AdminPermissionContext.put(req,
                    new edu.bingol.backend.admin.rbac.AdminPermissionContext(
                            edu.bingol.backend.admin.rbac.AdminProfile.FULL, false));
            s.revokeSessions(11L);
            verify(sessions).revokeAll(11L);
        } finally {
            RequestContextHolder.resetRequestAttributes();
        }
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
