package edu.bingol.backend.admin.users.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.AdminHierarchy;
import edu.bingol.backend.admin.rbac.AdminPermissionContext;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/** T-014: users.write sahibi FULL olmayan profil, yonetici hesabinin oturum/cihaz/profil kayitlarina dokunamaz. */
class AdminHierarchyServicesTest {

    private final UserRepository users = mock(UserRepository.class);
    private final DeviceRepository devices = mock(DeviceRepository.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);

    @AfterEach
    void reset() {
        RequestContextHolder.resetRequestAttributes();
    }

    private User target(long id, Role role) {
        User u = new User();
        u.setId(id);
        u.setRole(role);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    private void actingAs(AdminProfile p) {
        MockHttpServletRequest req = new MockHttpServletRequest();
        AdminPermissionContext.put(req, new AdminPermissionContext(p, false));
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(req));
    }

    private static void assertForbidden(Runnable r) {
        ApiException e = assertThrows(ApiException.class, r::run);
        assertEquals("ADMIN_TARGET_FORBIDDEN", e.code());
        assertEquals(403, e.status().value());
    }

    @Test
    void nonFullProfilesCannotRevokeSessionsOrDeleteDevicesOfAdmins() {
        target(5L, Role.ADMIN);
        var sessions = new AdminUserSessionService(redis, users, new JwtProperties("s", 15, 90), Clock.systemUTC());
        var push = new AdminPushDeviceService(devices, users);
        for (AdminProfile p : new AdminProfile[] {AdminProfile.MODERATOR, AdminProfile.SUPPORT, AdminProfile.EDITOR,
                AdminProfile.VIEWER}) {
            actingAs(p);
            assertForbidden(() -> sessions.revoke(5L, "aaaaaaaaaaaaaaaa"));
            assertForbidden(() -> push.delete(5L, 9L));
        }
        verify(devices, never()).delete(org.mockito.ArgumentMatchers.any(Device.class));
    }

    @Test
    void fullProfileAndNormalUsersAreNotRestricted() {
        target(5L, Role.ADMIN);
        target(6L, Role.USER);
        actingAs(AdminProfile.FULL);
        AdminHierarchy.requireManageable(users.findById(5L).orElseThrow());
        actingAs(AdminProfile.MODERATOR);
        AdminHierarchy.requireManageable(users.findById(6L).orElseThrow()); // normal kullanici serbest
        AdminHierarchy.requireManageable(null);
    }

    @Test
    void noRequestContextMeansNoRestriction() {
        // zamanlayici/birim testi baglaminda kisitlama yok (PermissionAwareMasking ile ayni kural)
        AdminHierarchy.requireManageable(target(5L, Role.ADMIN));
    }

    @Test
    void profilePatchTargetHierarchyAppliesThroughTargets() {
        target(5L, Role.ADMIN);
        actingAs(AdminProfile.MODERATOR);
        assertForbidden(() -> Targets.manageable(users, 5L));
        actingAs(AdminProfile.FULL);
        assertEquals(5L, Targets.manageable(users, 5L).getId());
    }
}
