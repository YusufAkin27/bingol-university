package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.users.extras.UserExtrasDtos.ProfilePatch;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.ProfilePatchResult;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AdminUserProfileServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final ProfileService profiles = mock(ProfileService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final AdminUserProfileService service = new AdminUserProfileService(users, profiles, notifications);

    private User user(long id) {
        User u = new User();
        u.setId(id);
        u.setRole(Role.USER);
        u.setStatus(UserStatus.ACTIVE);
        u.setDisplayName("Eski Ad");
        u.setBio("uygunsuz biyografi");
        u.setAvatarUrl("/files/avatars/x.jpg");
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    @Test
    void clearsAvatarBioAndRenamesThenNotifiesUser() {
        User u = user(5);

        ProfilePatchResult r = service.patch(5L, new ProfilePatch(true, true, "  Yeni   Ad ", null), "kurallara aykırı");

        assertTrue(r.avatarCleared() && r.bioCleared() && r.displayNameChanged());
        assertNull(u.getBio());
        assertEquals("Yeni Ad", u.getDisplayName());
        verify(profiles).removeAvatar(5L);
        verify(users).save(u);
        verify(notifications).sendLocalized(eq(5L), eq(NotificationType.SYSTEM), eq("notif.profile.moderated.title"),
                eq("notif.profile.moderated.body"), eq(null), eq(null));
    }

    @Test
    void alreadyEmptyFieldsMeanNoChangeAndNoNotification() {
        User u = user(5);
        u.setBio(null);
        u.setAvatarUrl(null);

        ProfilePatchResult r = service.patch(5L, new ProfilePatch(true, true, null, null), "gerekçe yeterli");

        assertFalse(r.changed());
        verify(profiles, never()).removeAvatar(any());
        verify(users, never()).save(any());
        verify(notifications, never()).sendLocalized(any(), any(), anyString(), any(), any(), any());
    }

    @Test
    void invalidDisplayNameChangesNothing() {
        User u = user(5);
        ApiException e = assertThrows(ApiException.class,
                () -> service.patch(5L, new ProfilePatch(true, true, "x", null), "gerekçe yeterli"));
        assertEquals(400, e.status().value());
        assertEquals("uygunsuz biyografi", u.getBio());
        verify(profiles, never()).removeAvatar(any());
        verify(users, never()).save(any());
    }

    @Test
    void emptyPatchAndShortReasonAreRejected() {
        user(5);
        assertEquals("PROFILE_PATCH_EMPTY", assertThrows(ApiException.class,
                () -> service.patch(5L, new ProfilePatch(false, null, null, null), "gerekçe yeterli")).code());
        assertEquals("REASON_REQUIRED", assertThrows(ApiException.class,
                () -> service.patch(5L, new ProfilePatch(true, null, null, null), "abc")).code());
        verify(profiles, never()).removeAvatar(any());
    }

    @Test
    void deletedUserIsNotFound() {
        User u = user(5);
        u.setStatus(UserStatus.DELETED);
        assertEquals("USER_NOT_FOUND", assertThrows(ApiException.class,
                () -> service.patch(5L, new ProfilePatch(true, null, null, null), "gerekçe yeterli")).code());
    }

    @Test
    void notificationFailureDoesNotBreakTheIntervention() {
        user(5);
        doThrow(new IllegalStateException("fcm")).when(notifications)
                .sendLocalized(any(), any(), anyString(), any(), any(), any());

        ProfilePatchResult r = service.patch(5L, new ProfilePatch(null, true, null, null), "gerekçe yeterli");

        assertTrue(r.bioCleared());
    }
}
