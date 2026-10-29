package edu.bingol.backend.admin.rbac;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.admin.AdminGuardPolicy;
import org.junit.jupiter.api.Test;

/** DS1 izinleri: okuma FULL+VIEWER, disa aktarma/silme yalniz FULL; gerekce ve yikici sinir. */
class RetentionPermissionTest {

    private static String perm(String m, String p) {
        return AdminPermissionPolicy.required(m, p);
    }

    @Test
    void endpointsMapToRetentionPermissions() {
        assertThat(perm("GET", "/api/admin/system/storage")).isEqualTo(PermissionMatrix.RETENTION_READ);
        assertThat(perm("GET", "/api/admin/data-retention/tables")).isEqualTo(PermissionMatrix.RETENTION_READ);
        assertThat(perm("GET", "/api/admin/data-retention/tables/admin_audit/purge-preview"))
                .isEqualTo(PermissionMatrix.RETENTION_READ);
        assertThat(perm("GET", "/api/admin/data-retention/exports/3")).isEqualTo(PermissionMatrix.RETENTION_READ);
        assertThat(perm("POST", "/api/admin/data-retention/exports")).isEqualTo(PermissionMatrix.RETENTION_EXPORT);
        assertThat(perm("POST", "/api/admin/data-retention/purges")).isEqualTo(PermissionMatrix.RETENTION_PURGE);
        // sistem alanindaki diger yollar eskisi gibi
        assertThat(perm("GET", "/api/admin/system/overview")).isEqualTo(PermissionMatrix.SYSTEM_READ);
    }

    @Test
    void onlyFullExportsAndPurgesViewerReadsOthersNothing() {
        for (AdminProfile p : AdminProfile.values()) {
            boolean full = p == AdminProfile.FULL;
            assertThat(PermissionMatrix.allows(p, PermissionMatrix.RETENTION_EXPORT)).as(p + " export").isEqualTo(full);
            assertThat(PermissionMatrix.allows(p, PermissionMatrix.RETENTION_PURGE)).as(p + " purge").isEqualTo(full);
            assertThat(PermissionMatrix.allows(p, PermissionMatrix.RETENTION_READ)).as(p + " read")
                    .isEqualTo(full || p == AdminProfile.VIEWER);
        }
    }

    @Test
    void exportAndPurgeRequireReasonAndCountAsDestructive() {
        assertThat(AdminGuardPolicy.reasonMin("POST", "/api/admin/data-retention/exports")).isEqualTo(5);
        assertThat(AdminGuardPolicy.reasonMin("POST", "/api/admin/data-retention/purges")).isEqualTo(5);
        assertThat(AdminGuardPolicy.destructive("POST", "/api/admin/data-retention/purges")).isTrue();
        assertThat(AdminGuardPolicy.reasonMin("GET", "/api/admin/data-retention/tables")).isZero();
    }
}
