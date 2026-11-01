package edu.bingol.backend.admin.twofactor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.admin.AdminDtos.AdminUserDetail;
import edu.bingol.backend.admin.AdminDtos.AdminUserRow;
import edu.bingol.backend.admin.AdminDtos.Counts;
import edu.bingol.backend.admin.UserFilter;
import edu.bingol.backend.admin.rbac.AdminPermissionContext;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/** Yonetici kullanici DTO'lari ve suzgeci: 2FA alanlari maskelemeden etkilenmez; SQL suzgeci parametrelidir. */
class AdminUserTwoFactorDtoTest {

    private static AdminUserRow row() {
        return new AdminUserRow(1L, "ali.veli@bingol.edu.tr", "Ali", null, null, null, "tr", Role.USER,
                UserStatus.ACTIVE, true, null, null, null, true);
    }

    private static AdminUserDetail detail() {
        return new AdminUserDetail(1L, "ali.veli@bingol.edu.tr", "Ali", null, null, null, "tr", Role.USER,
                UserStatus.ACTIVE, true, null, null, null, null, null, null, 0, List.of(),
                new Counts(0, 0, 0, 0, 0, 0, 0, 0), List.of(), List.of(), null, true, 3, "2026-11-01T10:00:00Z");
    }

    private static void asProfile(AdminProfile p) {
        MockHttpServletRequest req = new MockHttpServletRequest();
        AdminPermissionContext.put(req, new AdminPermissionContext(p, false));
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(req));
    }

    @Test
    void maskedProfilesKeepTheTwoFactorFieldsAndMaskOnlyTheEmail() {
        try {
            asProfile(AdminProfile.VIEWER);
            AdminUserRow r = row().masked();
            assertEquals("a***@bingol.edu.tr", r.email());
            assertTrue(r.twoFactorEnabled());
            AdminUserDetail d = detail().masked();
            assertEquals("a***@bingol.edu.tr", d.email());
            assertTrue(d.twoFactorEnabled());
            assertEquals(3, d.twoFactorTrustedDeviceCount());
            assertEquals("2026-11-01T10:00:00Z", d.twoFactorEnabledAt());
        } finally {
            RequestContextHolder.resetRequestAttributes();
        }
    }

    @Test
    void fullProfileSeesEverythingUnchanged() {
        try {
            asProfile(AdminProfile.FULL);
            assertEquals("ali.veli@bingol.edu.tr", row().masked().email());
            assertTrue(detail().masked().twoFactorEnabled());
        } finally {
            RequestContextHolder.resetRequestAttributes();
        }
    }

    @Test
    void twoFactorFilterIsABoundParameterOnlyWhenGiven() {
        UserFilter.Where on = new UserFilter(null, null, null, null, null, null, null, null, null, null, null, null, true).where();
        assertTrue(on.sql().contains("two_factor_enabled = :twoFactor"), on.sql());
        assertEquals(true, on.params().getValue("twoFactor"));
        assertFalse(on.sql().contains("true"), "deger SQL'e gomulmez: " + on.sql());

        UserFilter.Where off = new UserFilter(null, null, null, null, null, null, null, null, null, null, null, null, false).where();
        assertEquals(false, off.params().getValue("twoFactor"));

        UserFilter.Where none = new UserFilter(null, null, null, null, null, null, null, null).where();
        assertEquals("TRUE", none.sql());
        assertFalse(none.params().hasValue("twoFactor"));
        assertNull(new UserFilter(null, null, null, null, null, null, null, null, null, null, null, null).twoFactor());
    }
}
