package edu.bingol.backend.admin.rbac;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

/** Profil x uc izin kararlari (parametreli) + matris degismezleri. */
class AdminPermissionPolicyTest {

    private record Req(String method, String path) {
        @Override
        public String toString() {
            return method + " " + path;
        }
    }

    private static Req r(String m, String p) {
        return new Req(m, p);
    }

    private static boolean allowed(AdminProfile p, Req q) {
        return PermissionMatrix.allows(p, AdminPermissionPolicy.required(q.method(), q.path()));
    }

    /** Her profil icin IZIN VERILEN ornek istekler. */
    private static List<Req> allowedFor(AdminProfile p) {
        return switch (p) {
            case FULL -> List.of(r("PATCH", "/api/admin/users/3/role"), r("DELETE", "/api/admin/users/3"),
                    r("POST", "/api/admin/legal/terms"), r("PUT", "/api/admin/settings/banner_text"),
                    r("POST", "/api/admin/push/campaigns"), r("POST", "/api/admin/crypto/rewrap"),
                    r("PUT", "/api/admin/rbac/users/3/profile"), r("GET", "/api/admin/yeni-bilinmeyen-modul"),
                    r("POST", "/api/admin/ops/mail-outbox/retry-dead"), r("GET", "/api/admin/audit"));
            case MODERATOR -> List.of(r("GET", "/api/admin/users"), r("GET", "/api/admin/users/3/sessions"),
                    r("POST", "/api/admin/users/3/suspend"), r("PATCH", "/api/admin/users/3/profile"),
                    r("GET", "/api/admin/reports"), r("GET", "/api/admin/reports/3"), r("POST", "/api/admin/reports/3/resolve"),
                    r("POST", "/api/admin/moderation/blocklist"), r("POST", "/api/admin/access-bans"),
                    r("GET", "/api/admin/users/3/conversations"), r("POST", "/api/admin/messages/3/hide"),
                    r("POST", "/api/admin/posts/3/hide"), r("DELETE", "/api/admin/posts/3"),
                    r("GET", "/api/admin/news"), r("GET", "/api/admin/me"), r("GET", "/api/admin/rbac/me"),
                    r("GET", "/api/admin/analytics/overview"), r("GET", "/api/admin/legal/terms/versions"));
            case SUPPORT -> List.of(r("GET", "/api/admin/users"), r("GET", "/api/admin/users/3"),
                    r("GET", "/api/admin/support/tickets"), r("POST", "/api/admin/support/tickets/3/notes"),
                    r("POST", "/api/admin/support/tickets/3/reply"), r("PATCH", "/api/admin/support/tickets/3"),
                    r("POST", "/api/admin/push/users/3/send"), r("GET", "/api/admin/mail/campaigns"),
                    r("GET", "/api/admin/news"), r("GET", "/api/admin/rbac/matrix"));
            case EDITOR -> List.of(r("POST", "/api/admin/news/bulk"), r("PATCH", "/api/admin/news/3"),
                    r("PUT", "/api/admin/menu/2026-01-01/image"), r("PUT", "/api/admin/menu/2026-01-01/calories"), r("PUT", "/api/admin/menu/calories"),
                    r("GET", "/api/admin/menu"), r("POST", "/api/admin/communities/3/approve"),
                    r("POST", "/api/admin/announcements"), r("POST", "/api/admin/announcements/3/publish"),
                    r("POST", "/api/admin/events/3/hide"), r("POST", "/api/admin/mail/templates"),
                    r("POST", "/api/admin/polls/bulk"), r("POST", "/api/admin/faq"),
                    r("GET", "/api/admin/community-categories"), r("GET", "/api/admin/mail/campaigns"));
            case VIEWER -> List.of(r("GET", "/api/admin/users"), r("GET", "/api/admin/reports"), r("GET", "/api/admin/reports/export.csv"),
                    r("GET", "/api/admin/ops/health"), r("GET", "/api/admin/audit"),
                    r("GET", "/api/admin/settings"), r("GET", "/api/admin/support/tickets"),
                    r("GET", "/api/admin/analytics/overview"), r("GET", "/api/admin/mail/outbox"),
                    r("GET", "/api/admin/push/outbox"), r("GET", "/api/admin/news"), r("GET", "/api/admin/menu"));
        };
    }

    /** Her profil icin REDDEDILEN ornek istekler. */
    private static List<Req> deniedFor(AdminProfile p) {
        return switch (p) {
            case FULL -> List.of();
            case MODERATOR -> List.of(r("PATCH", "/api/admin/users/3/role"), r("DELETE", "/api/admin/users/3"),
                    r("PUT", "/api/admin/settings/banner_text"), r("POST", "/api/admin/legal/terms"),
                    r("POST", "/api/admin/push/campaigns"), r("GET", "/api/admin/ops/health"),
                    r("GET", "/api/admin/audit"), r("POST", "/api/admin/news/bulk"),
                    r("PUT", "/api/admin/rbac/users/3/profile"), r("GET", "/api/admin/rbac/admins"),
                    r("POST", "/api/admin/crypto/rewrap"), r("GET", "/api/admin/users/export.csv"),
                    r("POST", "/api/admin/support/tickets/3/notes"), r("GET", "/api/admin/yeni-bilinmeyen-modul"));
            case SUPPORT -> List.of(r("PATCH", "/api/admin/users/3/profile"), r("POST", "/api/admin/users/3/suspend"),
                    r("GET", "/api/admin/users/3/sessions"), r("GET", "/api/admin/reports"),
                    r("POST", "/api/admin/push/campaigns"), r("GET", "/api/admin/ops/health"),
                    r("GET", "/api/admin/users/3/conversations"), r("PATCH", "/api/admin/users/3/role"),
                    r("POST", "/api/admin/mail/campaigns"),
                    r("GET", "/api/admin/audit"), r("GET", "/api/admin/pending-registrations"));
            case EDITOR -> List.of(r("GET", "/api/admin/users"), r("POST", "/api/admin/push/campaigns"),
                    r("GET", "/api/admin/reports"), r("GET", "/api/admin/audit"), r("GET", "/api/admin/support/tickets"),
                    r("POST", "/api/admin/push/users/3/send"), r("POST", "/api/admin/messages/3/hide"),
                    r("POST", "/api/admin/legal/terms"), r("PUT", "/api/admin/settings/banner_text"),
                    r("GET", "/api/admin/chat-messages"), r("POST", "/api/admin/sync"));
            case VIEWER -> List.of(r("PUT", "/api/admin/menu/2026-01-01/calories"), r("PUT", "/api/admin/menu/calories"),
                    r("GET", "/api/admin/reports/3"), r("POST", "/api/admin/support/tickets/3/notes"), r("PATCH", "/api/admin/news/3"),
                    r("GET", "/api/admin/chat-messages"), r("GET", "/api/admin/users/export.csv"),
                    r("GET", "/api/admin/users/3/sessions"), r("POST", "/api/admin/users/3/suspend"),
                    r("POST", "/api/admin/reports/3/resolve"), r("PUT", "/api/admin/settings/banner_text"),
                    r("POST", "/api/admin/ops/mail-outbox/retry-dead"), r("GET", "/api/admin/rbac/admins"),
                    r("POST", "/api/admin/announcements"), r("POST", "/api/admin/push/outbox/3/retry"));
        };
    }

    @ParameterizedTest
    @EnumSource(AdminProfile.class)
    void allowedRequests(AdminProfile p) {
        List<String> wrong = new ArrayList<>();
        for (Req q : allowedFor(p)) {
            if (!allowed(p, q)) {
                wrong.add(p + " should be ALLOWED: " + q + " needs " + AdminPermissionPolicy.required(q.method(), q.path()));
            }
        }
        assertThat(wrong).isEmpty();
    }

    @ParameterizedTest
    @EnumSource(AdminProfile.class)
    void deniedRequests(AdminProfile p) {
        List<String> wrong = new ArrayList<>();
        for (Req q : deniedFor(p)) {
            if (allowed(p, q)) {
                wrong.add(p + " should be DENIED: " + q + " needs " + AdminPermissionPolicy.required(q.method(), q.path()));
            }
        }
        assertThat(wrong).isEmpty();
    }

    @Test
    void fullHoldsEveryPermission() {
        for (String perm : PermissionMatrix.allPermissions()) {
            assertThat(PermissionMatrix.allows(AdminProfile.FULL, perm)).as(perm).isTrue();
        }
    }

    @Test
    void sensitivePermissionsAreFullOnly() {
        for (String perm : List.of(PermissionMatrix.USERS_ROLE, PermissionMatrix.USERS_DELETE,
                PermissionMatrix.LEGAL_PUBLISH, PermissionMatrix.SETTINGS_WRITE, PermissionMatrix.COMMS_SEND,
                PermissionMatrix.SYSTEM_WRITE, PermissionMatrix.RBAC_MANAGE, PermissionMatrix.USERS_EXPORT)) {
            for (AdminProfile p : AdminProfile.values()) {
                assertThat(PermissionMatrix.allows(p, perm)).as(p + " " + perm).isEqualTo(p == AdminProfile.FULL);
            }
        }
    }

    @Test
    void maskedProfilesLackPii() {
        assertThat(PermissionMatrix.allows(AdminProfile.SUPPORT, PermissionMatrix.USERS_READ)).isTrue();
        assertThat(PermissionMatrix.allows(AdminProfile.VIEWER, PermissionMatrix.USERS_READ)).isTrue();
        assertThat(PermissionMatrix.allows(AdminProfile.SUPPORT, PermissionMatrix.USERS_PII)).isFalse();
        assertThat(PermissionMatrix.allows(AdminProfile.VIEWER, PermissionMatrix.USERS_PII)).isFalse();
        assertThat(PermissionMatrix.allows(AdminProfile.MODERATOR, PermissionMatrix.USERS_PII)).isTrue();
    }

    @Test
    void chatReadOnlyForFullAndModerator() {
        for (AdminProfile p : AdminProfile.values()) {
            boolean expect = p == AdminProfile.FULL || p == AdminProfile.MODERATOR;
            assertThat(PermissionMatrix.allows(p, PermissionMatrix.CHAT_READ)).as(p.name()).isEqualTo(expect);
        }
    }

    @Test
    void pathNormalizationAndHead() {
        assertThat(AdminPermissionPolicy.required("GET", "/api/admin/users/")).isEqualTo(PermissionMatrix.USERS_READ);
        assertThat(AdminPermissionPolicy.required("HEAD", "/api/admin/users")).isEqualTo(PermissionMatrix.USERS_READ);
        assertThat(AdminPermissionPolicy.required("GET", "/api/admin/users?x=1")).isEqualTo(PermissionMatrix.USERS_READ);
        assertThat(AdminPermissionPolicy.required("DELETE", "/api/admin/users/3")).isEqualTo(PermissionMatrix.USERS_DELETE);
        // path'te yonetici disi onek karisikligi: /api/adminx eslenmez
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/adminx/users")).isEmpty();
    }

    @Test
    void permissionDeniedMessageExistsInAllLanguages() {
        var ms = new org.springframework.context.support.ResourceBundleMessageSource();
        ms.setBasename("i18n/rbac");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false); // uygulamadaki ayar (spring.messages.fallback-to-system-locale=false)
        String tr = ms.getMessage("error.ADMIN_PERMISSION_DENIED", new Object[] {"users.role"}, java.util.Locale.forLanguageTag("tr"));
        String en = ms.getMessage("error.ADMIN_PERMISSION_DENIED", new Object[] {"users.role"}, java.util.Locale.ENGLISH);
        String ar = ms.getMessage("error.ADMIN_PERMISSION_DENIED", new Object[] {"users.role"}, java.util.Locale.forLanguageTag("ar"));
        assertThat(tr).contains("users.role").startsWith("Bu i");
        assertThat(en).contains("users.role").startsWith("You do not have permission");
        assertThat(ar).contains("users.role");
        assertThat(ar).isNotEqualTo(en);
    }

    @Test
    void userDtosMaskEmailOnlyForMaskedProfiles() {
        var row = new edu.bingol.backend.admin.AdminDtos.AdminUserRow(1L, "ali.veli@bingol.edu.tr", "Ali", null, null,
                null, "tr", edu.bingol.backend.user.Role.USER, edu.bingol.backend.user.UserStatus.ACTIVE, true, null, null, null);
        // istek baglami yok => maskesiz
        assertThat(row.masked().email()).isEqualTo("ali.veli@bingol.edu.tr");
        try {
            for (AdminProfile p : AdminProfile.values()) {
                var req = new org.springframework.mock.web.MockHttpServletRequest();
                AdminPermissionContext.put(req, new AdminPermissionContext(p, false));
                org.springframework.web.context.request.RequestContextHolder.setRequestAttributes(
                        new org.springframework.web.context.request.ServletRequestAttributes(req));
                boolean masked = !PermissionMatrix.allows(p, PermissionMatrix.USERS_PII);
                assertThat(row.masked().email()).as(p.name())
                        .isEqualTo(masked ? "a***@bingol.edu.tr" : "ali.veli@bingol.edu.tr");
                assertThat(PermissionAwareMasking.opaque("10.0.0.1")).isEqualTo(masked ? "***" : "10.0.0.1");
            }
        } finally {
            org.springframework.web.context.request.RequestContextHolder.resetRequestAttributes();
        }
    }

    @Test
    void maskEmail() {
        assertThat(PermissionAwareMasking.maskEmail("ali.veli@bingol.edu.tr")).isEqualTo("a***@bingol.edu.tr");
        assertThat(PermissionAwareMasking.maskEmail(null)).isNull();
        assertThat(PermissionAwareMasking.maskEmail("bozuk")).isEqualTo("***");
        // istek baglami yokken maskeleme yok (birim testleri/zamanlayici)
        assertThat(PermissionAwareMasking.email("ali@bingol.edu.tr")).isEqualTo("ali@bingol.edu.tr");
    }
}
