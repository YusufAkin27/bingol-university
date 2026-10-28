package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkAction;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkItemResult;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkResult;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.BulkStatus;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.moderation.UserModerationService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AdminUserBulkServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final UserModerationService moderation = mock(UserModerationService.class);
    private final SessionService sessions = mock(SessionService.class);
    private final AdminProperties admin = new AdminProperties(List.of("pinli@bingol.edu.tr"));
    private final AdminUserBulkService service = new AdminUserBulkService(users, moderation, sessions, admin);

    private User user(long id, Role role, UserStatus status, String email) {
        User u = new User();
        u.setId(id);
        u.setRole(role);
        u.setStatus(status);
        u.setEmail(email);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    private static BulkItemResult of(BulkResult r, long id) {
        return r.results().stream().filter(x -> x.id() == id).findFirst().orElseThrow();
    }

    @Test
    void partialSuccessReportAndProtections() {
        user(2, Role.USER, UserStatus.ACTIVE, "a@bingol.edu.tr");
        user(3, Role.ADMIN, UserStatus.ACTIVE, "yonetici@bingol.edu.tr");
        user(4, Role.USER, UserStatus.ACTIVE, "Pinli@bingol.edu.tr"); // ADMIN_EMAILS'te (rol henuz USER)
        user(5, Role.USER, UserStatus.SUSPENDED, "b@bingol.edu.tr");
        user(6, Role.USER, UserStatus.DELETED, "deleted-6@deleted.invalid");
        user(1, Role.ADMIN, UserStatus.ACTIVE, "ben@bingol.edu.tr"); // yonetici kendisi
        when(users.findById(99L)).thenReturn(Optional.empty());

        BulkResult r = service.run(1L, BulkAction.SUSPEND, List.of(1L, 2L, 3L, 4L, 5L, 6L, 99L), "toplu askı sebebi");

        assertEquals(7, r.requested());
        assertEquals(1, r.done());
        assertEquals(4, r.skipped());
        assertEquals(2, r.failed());
        assertEquals(BulkStatus.DONE, of(r, 2).status());
        assertEquals("SELF", of(r, 1).code());
        assertEquals("ADMIN_TARGET", of(r, 3).code());
        assertEquals("ADMIN_EMAIL_PINNED", of(r, 4).code());
        assertEquals("ALREADY_SUSPENDED", of(r, 5).code());
        assertEquals(BulkStatus.FAILED, of(r, 6).status());
        assertEquals("USER_NOT_FOUND", of(r, 99).code());
        verify(moderation).suspend(2L, "toplu askı sebebi");
        verify(moderation, never()).suspend(3L, "toplu askı sebebi");
        verify(moderation, never()).suspend(1L, "toplu askı sebebi");
        verify(moderation, never()).suspend(4L, "toplu askı sebebi");
    }

    @Test
    void oneFailureDoesNotStopTheOthers() {
        user(2, Role.USER, UserStatus.ACTIVE, "a@bingol.edu.tr");
        user(3, Role.USER, UserStatus.ACTIVE, "c@bingol.edu.tr");
        doThrow(new IllegalStateException("redis down")).when(sessions).revokeAll(2L);

        BulkResult r = service.run(1L, BulkAction.REVOKE_SESSIONS, List.of(2L, 3L), "oturum kapatma");

        assertEquals(1, r.done());
        assertEquals(1, r.failed());
        assertEquals("INTERNAL_ERROR", of(r, 2).code());
        verify(sessions).revokeAll(3L);
    }

    @Test
    void unsuspendOnlyTouchesSuspendedUsers() {
        user(2, Role.USER, UserStatus.SUSPENDED, "a@bingol.edu.tr");
        user(3, Role.USER, UserStatus.ACTIVE, "c@bingol.edu.tr");

        BulkResult r = service.run(1L, BulkAction.UNSUSPEND, List.of(2L, 3L), "geri açma");

        assertEquals(1, r.done());
        assertEquals("NOT_SUSPENDED", of(r, 3).code());
        verify(moderation).unsuspend(2L);
        verify(moderation, never()).unsuspend(3L);
    }

    @Test
    void moderationApiExceptionBecomesFailedCode() {
        user(2, Role.USER, UserStatus.ACTIVE, "a@bingol.edu.tr");
        doThrow(new ApiException(org.springframework.http.HttpStatus.BAD_REQUEST, "CANNOT_SUSPEND_ADMIN", "x"))
                .when(moderation).suspend(2L, "yeterli sebep");

        BulkResult r = service.run(1L, BulkAction.SUSPEND, List.of(2L), "yeterli sebep");

        assertEquals("CANNOT_SUSPEND_ADMIN", of(r, 2).code());
        assertEquals(1, r.failed());
    }

    @Test
    void idsAreDeduplicatedAndLimited() {
        user(2, Role.USER, UserStatus.ACTIVE, "a@bingol.edu.tr");
        BulkResult r = service.run(1L, BulkAction.REVOKE_SESSIONS, List.of(2L, 2L, 2L), "yeterli sebep");
        assertEquals(1, r.requested());

        List<Long> many = new ArrayList<>();
        for (long i = 1; i <= 101; i++) {
            many.add(i + 1000);
        }
        ApiException e = assertThrows(ApiException.class,
                () -> service.run(1L, BulkAction.SUSPEND, many, "yeterli sebep"));
        assertEquals("USER_BULK_LIMIT", e.code());
        assertEquals(400, e.status().value());
        verify(moderation, never()).suspend(any(), anyString());

        ApiException empty = assertThrows(ApiException.class,
                () -> service.run(1L, BulkAction.SUSPEND, List.of(), "yeterli sebep"));
        assertEquals("VALIDATION_ERROR", empty.code());
    }

    @Test
    void reasonIsRequired() {
        ApiException e = assertThrows(ApiException.class,
                () -> service.run(1L, BulkAction.SUSPEND, List.of(2L), "ab"));
        assertEquals("REASON_REQUIRED", e.code());
        verify(users, never()).findById(any());
    }
}
