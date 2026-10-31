package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.privacy.AvatarCleanups;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.password.PasswordEncoder;

/** T-002: yonetici DELETE /api/users/me ile kendini silemez; silinen hesapta rol/oturum temizligi. */
class AdminSelfDeleteTest {

    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder enc = mock(PasswordEncoder.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final AccountDataPurger purger = mock(AccountDataPurger.class);
    private final SessionService sessions = mock(SessionService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);

    private ProfileService service(String... pinnedAdmins) {
        when(redis.opsForValue()).thenReturn(ops);
        when(enc.matches(any(), any())).thenReturn(true);
        when(enc.encode(any())).thenReturn("h");
        when(rsvps.findByUserId(any())).thenReturn(List.of());
        ProfileService s = new ProfileService(users, mock(BlockService.class), mock(MediaService.class), enc,
                mock(AppInfoService.class), mock(ActivityRepository.class), mock(PublicProfileMapper.class),
                mock(AvatarCleanups.class), rsvps, mock(UserEventRepository.class), redis, purger, null);
        s.setAdminProperties(new AdminProperties(List.of(pinnedAdmins)));
        s.setSessions(sessions);
        return s;
    }

    private User user(long id, Role role, String email) {
        User u = new User();
        u.setId(id);
        u.setEmail(email);
        u.setRole(role);
        u.setPasswordHash("hash");
        u.setStatus(UserStatus.ACTIVE);
        if (role == Role.ADMIN) {
            u.setAdminProfile(AdminProfile.FULL);
        }
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    @Test
    void soleAdministratorCannotDeleteTheOwnAccount() {
        User admin = user(1L, Role.ADMIN, "boss@bingol.edu.tr");
        when(users.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE)).thenReturn(1L);

        ApiException e = assertThrows(ApiException.class, () -> service().deleteAccount(1L, "pw"));

        assertEquals("ADMIN_CANNOT_SELF_DELETE", e.code());
        assertEquals(409, e.status().value());
        assertEquals(UserStatus.ACTIVE, admin.getStatus());
        verify(purger, never()).purge(any());
    }

    @Test
    void anAdministratorCannotSelfDeleteEvenWhenOtherAdministratorsExist() {
        user(1L, Role.ADMIN, "second@bingol.edu.tr");
        when(users.countByRoleAndStatus(Role.ADMIN, UserStatus.ACTIVE)).thenReturn(3L);

        ApiException e = assertThrows(ApiException.class, () -> service().deleteAccount(1L, "pw"));

        assertEquals("ADMIN_CANNOT_SELF_DELETE", e.code());
        verify(purger, never()).purge(any());
    }

    @Test
    void adminEmailsAccountsAreProtectedEvenWithUserRole() {
        user(2L, Role.USER, "pinned@bingol.edu.tr");

        ApiException e = assertThrows(ApiException.class,
                () -> service("pinned@bingol.edu.tr").deleteAccount(2L, "pw"));

        assertEquals("ADMIN_CANNOT_SELF_DELETE", e.code());
    }

    @Test
    void wrongPasswordStillWinsOverTheAdminGuard() {
        user(1L, Role.ADMIN, "boss@bingol.edu.tr");
        ProfileService s = service();
        when(enc.matches(any(), any())).thenReturn(false);

        assertEquals("WRONG_PASSWORD", assertThrows(ApiException.class, () -> s.deleteAccount(1L, "x")).code());
    }

    @Test
    void ordinaryUserDeletionRevokesSessionsAfterWritingTheSuspendedMark() {
        user(3L, Role.USER, "ogr@bingol.edu.tr");

        service().deleteAccount(3L, "pw");

        InOrder order = inOrder(ops, sessions);
        order.verify(ops).set("suspended:3", "1");
        order.verify(sessions).revokeAll(3L);
        verify(purger).purge(3L);
    }

    @Test
    void anonymizingAnAdministratorViaThePanelDropsRoleAndProfile() {
        User admin = user(4L, Role.ADMIN, "eski.yonetici@bingol.edu.tr");

        service().anonymizeAccount(4L);

        assertEquals(Role.USER, admin.getRole());
        assertNull(admin.getAdminProfile());
        assertEquals(UserStatus.DELETED, admin.getStatus());
        verify(sessions).revokeAll(4L);
    }

    @Test
    void suspendedMarkAndSessionRevocationWaitForTheCommit() {
        user(5L, Role.USER, "ogr5@bingol.edu.tr");
        ProfileService s = service();
        org.springframework.transaction.support.TransactionSynchronizationManager.initSynchronization();
        try {
            s.deleteAccount(5L, "pw");

            verify(ops, never()).set("suspended:5", "1");
            verify(sessions, never()).revokeAll(5L);
            org.springframework.transaction.support.TransactionSynchronizationManager.getSynchronizations()
                    .forEach(org.springframework.transaction.support.TransactionSynchronization::afterCommit);
            verify(ops).set("suspended:5", "1");
            verify(sessions).revokeAll(5L);
        } finally {
            org.springframework.transaction.support.TransactionSynchronizationManager.clearSynchronization();
        }
    }
}
