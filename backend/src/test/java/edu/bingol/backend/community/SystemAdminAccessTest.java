package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMember.Status;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.post.PostController;
import edu.bingol.backend.post.PostService;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * T-040: sistem ADMIN rolu kullanici API'lerinde RBAC profilini atlamaz. VIEWER bile ROLE_ADMIN tasir ama kulup /
 * gonderi yonetemez; izinli profil mudahale eder ve admin_audit kaydi dusulur.
 */
class SystemAdminAccessTest {

    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final ClubMemberGrantRepository grants = mock(ClubMemberGrantRepository.class);
    private final SystemAdminAudit audit = mock(SystemAdminAudit.class);
    private final ClubPermissions permissions = new ClubPermissions(members, grants);

    SystemAdminAccessTest() {
        permissions.setAudit(audit);
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
        RequestContextHolder.resetRequestAttributes();
    }

    private static Actor viaApi(long id, AdminProfile p) {
        return new Actor(id, true, PermissionMatrix.permissionsOf(p));
    }

    private void login(long id, AdminProfile profile) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(id, null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))));
        MockHttpServletRequest req = new MockHttpServletRequest();
        if (profile != null) {
            req.setAttribute(JwtAuthFilter.ADMIN_PROFILE_ATTR, profile.name());
        }
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(req));
    }

    // ---- Actor / CurrentUser ----

    @Test
    void systemAdminDependsOnPermissionNotJustRole() {
        assertTrue(viaApi(1, AdminProfile.FULL).systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertTrue(viaApi(1, AdminProfile.EDITOR).systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertFalse(viaApi(1, AdminProfile.VIEWER).systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertFalse(viaApi(1, AdminProfile.MODERATOR).systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertTrue(viaApi(1, AdminProfile.VIEWER).systemAdmin(PermissionMatrix.CONTENT_READ));
        // admin API'sinin actor'u (izin kisiti yok) ve olmayan admin
        assertTrue(new Actor(1L, true).systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertFalse(new Actor(1L, false).systemAdmin(PermissionMatrix.CONTENT_READ));
        assertFalse(new Actor(1L, false, Set.of(PermissionMatrix.CONTENT_WRITE)).systemAdmin(PermissionMatrix.CONTENT_WRITE));
    }

    @Test
    void actorCurrentReadsProfileFromJwtClaim() {
        login(7, AdminProfile.VIEWER);
        Actor viewer = Actor.current();
        assertTrue(viewer.admin());
        assertFalse(viewer.systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertFalse(CurrentUser.hasAdminPermission(PermissionMatrix.CONTENT_HIDE));

        login(7, AdminProfile.FULL);
        assertTrue(Actor.current().systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertTrue(CurrentUser.hasAdminPermission(PermissionMatrix.CONTENT_HIDE));
    }

    @Test
    void adminWithoutProfileClaimFailsClosed() {
        login(7, null); // P16 oncesi eski token / istek baglami disi
        assertFalse(Actor.current().systemAdmin(PermissionMatrix.CONTENT_WRITE));
        assertTrue(CurrentUser.adminPermissions().isEmpty());
    }

    // ---- ClubPermissions ----

    @Test
    void viewerAdminCannotManageAClub() {
        Actor viewer = viaApi(7, AdminProfile.VIEWER);
        when(members.findByCommunityIdAndUserId(10L, 7L)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class, () -> permissions.require(viewer, 10L, ClubPermission.EDIT_INFO));

        assertEquals(403, e.status().value());
        assertFalse(permissions.has(viewer, 10L, ClubPermission.MANAGE_EVENTS));
        verify(audit, never()).record(any(), any(), any(), any());
    }

    @Test
    void fullAdminManagesAClubAndIsAudited() {
        Actor full = viaApi(1, AdminProfile.FULL);
        when(members.findByCommunityIdAndUserId(10L, 1L)).thenReturn(Optional.empty());

        permissions.require(full, 10L, ClubPermission.EDIT_INFO);

        verify(audit).record(eq(full), eq("COMMUNITY"), eq(10L), any());
        assertTrue(permissions.has(full, 10L, ClubPermission.MANAGE_ROLES));
    }

    @Test
    void adminActingAsRealOwnerIsNotAuditedAsOverride() {
        Actor full = viaApi(1, AdminProfile.FULL);
        CommunityMember m = new CommunityMember(10L, 1L, Role.OWNER, Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 1L)).thenReturn(Optional.of(m));
        when(grants.findByCommunityIdAndUserId(10L, 1L)).thenReturn(Optional.empty());

        permissions.require(full, 10L, ClubPermission.EDIT_INFO);

        verify(audit, never()).record(any(), any(), any(), any());
    }

    // ---- admin_audit satiri ----

    @Test
    void interventionWritesAnAdminAuditRowWithTargetAndRequestPath() {
        var ds = new org.springframework.jdbc.datasource.DriverManagerDataSource(
                "jdbc:h2:mem:sysaudit" + java.util.UUID.randomUUID().toString().replace("-", "") + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
        var jdbc = new org.springframework.jdbc.core.JdbcTemplate(ds);
        jdbc.execute("CREATE TABLE app_user (id BIGINT PRIMARY KEY, email VARCHAR(254))");
        jdbc.execute("CREATE TABLE admin_audit (id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, admin_id BIGINT, "
                + "admin_email VARCHAR(254), method VARCHAR(8) NOT NULL, path VARCHAR(300) NOT NULL, status INTEGER NOT NULL, "
                + "ip VARCHAR(64), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, target_type VARCHAR(32), "
                + "target_id VARCHAR(64), reason VARCHAR(300), summary VARCHAR(500), request_id VARCHAR(64))");
        jdbc.update("INSERT INTO app_user VALUES (1, 'boss@bingol.edu.tr')");
        MockHttpServletRequest req = new MockHttpServletRequest("DELETE", "/api/communities/10");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(req));
        SystemAdminAudit real = new SystemAdminAudit(jdbc, new edu.bingol.backend.common.ClientIp("127.0.0.0/8"));

        SystemAdminAudit.used(real, viaApi(1, AdminProfile.FULL), "COMMUNITY", 10L, "kulup silme");
        SystemAdminAudit.used(real, new Actor(1L, true), "COMMUNITY", 11L, "yonetici API'si kendi denetimini yazar");
        SystemAdminAudit.used(real, new Actor(1L, false), "COMMUNITY", 12L, "admin degil");

        var rows = jdbc.queryForList("SELECT * FROM admin_audit");
        assertEquals(1, rows.size());
        assertEquals("DELETE", rows.get(0).get("METHOD"));
        assertEquals("/api/communities/10", rows.get(0).get("PATH"));
        assertEquals("COMMUNITY", rows.get(0).get("TARGET_TYPE"));
        assertEquals("10", rows.get(0).get("TARGET_ID"));
        assertEquals("boss@bingol.edu.tr", rows.get(0).get("ADMIN_EMAIL"));
        assertTrue(String.valueOf(rows.get(0).get("SUMMARY")).contains("sistem-yonetici-mudahalesi"));
    }

    // ---- PostController.delete ----

    private PostController postController(PostService service, SystemAdminAudit a) {
        PostController c = new PostController(service, mock(RateLimiter.class));
        try {
            var m = PostController.class.getDeclaredMethod("setAdminAudit", SystemAdminAudit.class);
            m.setAccessible(true);
            m.invoke(c, a);
        } catch (ReflectiveOperationException ex) {
            throw new IllegalStateException(ex);
        }
        return c;
    }

    @Test
    void viewerCannotOverridePostDeletion() {
        PostService service = mock(PostService.class);
        login(7, AdminProfile.VIEWER);

        postController(service, audit).delete(55L);

        verify(service).delete(7L, 55L, false); // admin=false: baskasinin gonderisinde PostService 403 verir
        verify(audit, never()).record(any(), any(), any(), any());
    }

    @Test
    void fullAndModeratorOverridePostDeletionWithAudit() {
        for (AdminProfile p : List.of(AdminProfile.FULL, AdminProfile.MODERATOR, AdminProfile.EDITOR)) {
            PostService service = mock(PostService.class);
            SystemAdminAudit a = mock(SystemAdminAudit.class);
            login(7, p);

            postController(service, a).delete(55L);

            verify(service).delete(7L, 55L, true);
            verify(a).record(any(), eq("POST"), eq(55L), any());
        }
    }

    @Test
    void supportAdminCannotOverridePostDeletion() {
        PostService service = mock(PostService.class);
        login(7, AdminProfile.SUPPORT);

        postController(service, audit).delete(55L);

        verify(service).delete(7L, 55L, false);
    }
}
