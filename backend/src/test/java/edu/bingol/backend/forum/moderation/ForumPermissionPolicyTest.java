package edu.bingol.backend.forum.moderation;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.admin.rbac.AdminPermissionPolicy;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import org.junit.jupiter.api.Test;

/** Forum izin matrisi (profil -> izin) ve /api/admin/forum/** yol eslemesi (saf fonksiyon testi). */
class ForumPermissionPolicyTest {

    @Test
    void profilesGetTheDocumentedForumPermissions() {
        assertThat(PermissionMatrix.permissionsOf(AdminProfile.FULL)).contains("forum.read", "forum.moderate", "forum.categories");
        assertThat(PermissionMatrix.permissionsOf(AdminProfile.MODERATOR)).contains("forum.read", "forum.moderate")
                .doesNotContain("forum.categories");
        assertThat(PermissionMatrix.permissionsOf(AdminProfile.EDITOR)).contains("forum.read", "forum.categories")
                .doesNotContain("forum.moderate");
        assertThat(PermissionMatrix.permissionsOf(AdminProfile.VIEWER)).contains("forum.read")
                .doesNotContain("forum.moderate", "forum.categories");
        assertThat(PermissionMatrix.permissionsOf(AdminProfile.SUPPORT)).doesNotContain("forum.read", "forum.moderate",
                "forum.categories");
    }

    @Test
    void constantsAreKnownPermissions() {
        assertThat(PermissionMatrix.isKnown(PermissionMatrix.FORUM_READ)).isTrue();
        assertThat(PermissionMatrix.isKnown(PermissionMatrix.FORUM_MODERATE)).isTrue();
        assertThat(PermissionMatrix.isKnown(PermissionMatrix.FORUM_CATEGORIES)).isTrue();
    }

    @Test
    void adminForumPathsMapToExplicitPermissions() {
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/admin/forum/reports")).contains("forum.read");
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/admin/forum/actions")).contains("forum.read");
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/admin/forum/topics")).contains("forum.read");
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/admin/forum/categories")).contains("forum.read");
        assertThat(AdminPermissionPolicy.explicit("POST", "/api/admin/forum/topics/1/moderate")).contains("forum.moderate");
        assertThat(AdminPermissionPolicy.explicit("POST", "/api/admin/forum/comments/1/moderate")).contains("forum.moderate");
        assertThat(AdminPermissionPolicy.explicit("POST", "/api/admin/forum/categories")).contains("forum.categories");
        assertThat(AdminPermissionPolicy.explicit("PATCH", "/api/admin/forum/categories/3")).contains("forum.categories");
        assertThat(AdminPermissionPolicy.explicit("DELETE", "/api/admin/forum/categories/3")).contains("forum.categories");
        assertThat(AdminPermissionPolicy.explicit("POST", "/api/admin/forum/categories/reorder")).contains("forum.categories");
    }

    @Test
    void permissionDecisionPerProfile() {
        // MODERATOR kategori yazamaz, EDITOR moderasyon yapamaz, VIEWER yalniz okur
        assertThat(allows(AdminProfile.MODERATOR, "POST", "/api/admin/forum/topics/9/moderate")).isTrue();
        assertThat(allows(AdminProfile.MODERATOR, "POST", "/api/admin/forum/categories")).isFalse();
        assertThat(allows(AdminProfile.EDITOR, "POST", "/api/admin/forum/categories/reorder")).isTrue();
        assertThat(allows(AdminProfile.EDITOR, "POST", "/api/admin/forum/topics/9/moderate")).isFalse();
        assertThat(allows(AdminProfile.EDITOR, "GET", "/api/admin/forum/reports")).isTrue();
        assertThat(allows(AdminProfile.VIEWER, "GET", "/api/admin/forum/reports")).isTrue();
        assertThat(allows(AdminProfile.VIEWER, "POST", "/api/admin/forum/topics/9/moderate")).isFalse();
        assertThat(allows(AdminProfile.SUPPORT, "GET", "/api/admin/forum/topics")).isFalse();
        assertThat(allows(AdminProfile.FULL, "DELETE", "/api/admin/forum/categories/1")).isTrue();
    }

    private static boolean allows(AdminProfile p, String method, String path) {
        return PermissionMatrix.allows(p, AdminPermissionPolicy.required(method, path));
    }
}
