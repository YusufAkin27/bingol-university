package edu.bingol.backend.community.permissions;

import static edu.bingol.backend.community.permissions.ClubPermission.EDIT_INFO;
import static edu.bingol.backend.community.permissions.ClubPermission.INVITE;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_EVENTS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_MEMBERS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_POSTS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_ROLES;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.permissions.ClubDtos.AccessRequest;
import edu.bingol.backend.community.permissions.ClubDtos.AccessView;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

/** Yetki verme/alma ve yukseltme saldirilari. Kulup 10; sahip = 1. */
class ClubRoleServiceTest {

    private final ClubTestSupport t = new ClubTestSupport();
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final ClubRoleService svc = new ClubRoleService(t.communities, t.members, t.grants, t.permissions, audit,
            notifications);

    private final Actor owner = new Actor(1L, false);

    private static AccessRequest role(Role r) {
        return new AccessRequest(r, null, null);
    }

    private static AccessRequest template(String name) {
        return new AccessRequest(null, name, null);
    }

    private static AccessRequest perms(String... p) {
        return new AccessRequest(null, null, List.of(p));
    }

    private static String code(Runnable r) {
        return ClubTestSupport.error(r::run).code();
    }

    // ---- sahibin verdigi / geri aldigi yetkiler ----

    @Test
    void ownerGivesPostManagerTemplateToPlainMember() {
        t.member(1L, Role.OWNER);
        CommunityMember target = t.member(5L, Role.MEMBER);

        AccessView v = svc.setAccess(owner, 10L, 5L, template("POST_MANAGER"));

        assertEquals(Role.MEMBER, target.getRole());
        assertEquals(Set.of(MANAGE_POSTS), v.permissions());
        assertEquals("POST_MANAGER", v.template());
        ArgumentCaptor<ClubMemberGrant> g = ArgumentCaptor.forClass(ClubMemberGrant.class);
        verify(t.grants).save(g.capture());
        assertEquals(Set.of(MANAGE_POSTS), g.getValue().permissionSet());
        verify(audit).record(eq(10L), eq(1L), eq(5L), eq(ClubAuditService.PERMISSIONS_SET), anyString());
        verify(notifications).sendTemplated(eq(5L), eq(NotificationType.COMMUNITY), eq("notif.community.permsChanged"),
                any(), any(String[].class));
    }

    @Test
    void ownerGivesCustomPermissionSet() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);

        AccessView v = svc.setAccess(owner, 10L, 5L, perms("manage_events", "INVITE"));

        assertEquals(Set.of(MANAGE_EVENTS, INVITE), v.permissions());
        assertTrue(v.custom());
    }

    @Test
    void ownerAssignsModeratorWithDefaultsAndNoGrantRow() {
        t.member(1L, Role.OWNER);
        CommunityMember target = t.member(5L, Role.MEMBER);

        AccessView v = svc.setAccess(owner, 10L, 5L, role(Role.MODERATOR));

        assertEquals(Role.MODERATOR, target.getRole());
        assertEquals(Set.of(MANAGE_MEMBERS, MANAGE_POSTS, MANAGE_EVENTS, EDIT_INFO, INVITE), v.permissions());
        verify(t.grants).deleteMember(10L, 5L);
        verify(t.grants, never()).save(any());
    }

    @Test
    void ownerAssignsAdminAndCanGrantManageRolesOnlyToAdmin() {
        t.member(1L, Role.OWNER);
        CommunityMember target = t.member(5L, Role.MEMBER);

        svc.setAccess(owner, 10L, 5L, role(Role.ADMIN));
        assertEquals(Role.ADMIN, target.getRole());

        AccessView v = svc.setAccess(owner, 10L, 5L,
                new AccessRequest(null, null, List.of("MANAGE_ROLES", "MANAGE_POSTS")));
        assertEquals(Set.of(MANAGE_ROLES, MANAGE_POSTS), v.permissions());
    }

    @Test
    void manageRolesCannotBeGivenToNonAdmin() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        t.member(6L, Role.MODERATOR);

        assertEquals("MANAGE_ROLES_ADMIN_ONLY", code(() -> svc.setAccess(owner, 10L, 5L, perms("MANAGE_ROLES"))));
        assertEquals("MANAGE_ROLES_ADMIN_ONLY", code(() -> svc.setAccess(owner, 10L, 6L, perms("MANAGE_ROLES"))));
    }

    @Test
    void ownerRevokesByResettingToRoleDefaults() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);
        t.grant(5L, MANAGE_POSTS);

        AccessView v = svc.reset(owner, 10L, 5L);

        assertEquals(Set.of(), v.permissions());
        verify(t.grants).deleteMember(10L, 5L);
        verify(audit).record(eq(10L), eq(1L), eq(5L), eq(ClubAuditService.PERMISSIONS_RESET), anyString());
    }

    @Test
    void ownerCanRevokeEverythingFromModeratorWithEmptySet() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MODERATOR);

        AccessView v = svc.setAccess(owner, 10L, 5L, new AccessRequest(null, null, List.of()));

        assertEquals(Set.of(), v.permissions());
        ArgumentCaptor<ClubMemberGrant> g = ArgumentCaptor.forClass(ClubMemberGrant.class);
        verify(t.grants).save(g.capture());
        assertEquals("", g.getValue().getPermissions());
    }

    @Test
    void demotingAdminDropsManageRoles() {
        t.member(1L, Role.OWNER);
        CommunityMember admin = t.member(5L, Role.ADMIN);
        t.grant(5L, MANAGE_ROLES, MANAGE_POSTS);

        AccessView v = svc.setAccess(owner, 10L, 5L, role(Role.MODERATOR));

        assertEquals(Role.MODERATOR, admin.getRole());
        assertTrue(!v.permissions().contains(MANAGE_ROLES));
    }

    @Test
    void systemAdminActsAsOwnerWithoutMembership() {
        CommunityMember target = t.member(5L, Role.MEMBER);

        svc.setAccess(new Actor(500L, true), 10L, 5L, role(Role.MODERATOR));

        assertEquals(Role.MODERATOR, target.getRole());
    }

    // ---- yukseltme saldirilari ----

    @Test
    void moderatorCannotElevateOthers() {
        t.member(2L, Role.MODERATOR);
        t.member(5L, Role.MEMBER);
        Actor mod = new Actor(2L, false);

        assertEquals("FORBIDDEN", code(() -> svc.setAccess(mod, 10L, 5L, role(Role.MODERATOR))));
        assertEquals("FORBIDDEN", code(() -> svc.setAccess(mod, 10L, 5L, perms("MANAGE_POSTS"))));
        assertEquals("FORBIDDEN", code(() -> svc.setAccess(mod, 10L, 5L, template("POST_MANAGER"))));
        verify(t.members, never()).save(any());
        verify(t.grants, never()).save(any());
    }

    @Test
    void moderatorCannotElevateSelf() {
        t.member(2L, Role.MODERATOR);
        Actor mod = new Actor(2L, false);

        assertEquals("FORBIDDEN", code(() -> svc.setAccess(mod, 10L, 2L, role(Role.ADMIN))));
        assertEquals("FORBIDDEN", code(() -> svc.setAccess(mod, 10L, 2L, perms("MANAGE_ROLES"))));
    }

    @Test
    void plainAndCustomMembersCannotManageRoles() {
        t.member(3L, Role.MEMBER);
        t.member(4L, Role.MEMBER);
        t.grant(4L, MANAGE_MEMBERS, INVITE);
        t.member(5L, Role.MEMBER);

        assertEquals("FORBIDDEN", code(() -> svc.setAccess(new Actor(3L, false), 10L, 5L, role(Role.MODERATOR))));
        assertEquals("FORBIDDEN", code(() -> svc.setAccess(new Actor(4L, false), 10L, 5L, role(Role.MODERATOR))));
    }

    @Test
    void adminWithoutExplicitManageRolesCannotAssign() {
        t.member(2L, Role.ADMIN);
        t.member(5L, Role.MEMBER);

        assertEquals("FORBIDDEN", code(() -> svc.setAccess(new Actor(2L, false), 10L, 5L, role(Role.MODERATOR))));
    }

    @Test
    void ownerCannotChangeOwnPermissions() {
        t.member(1L, Role.OWNER);

        assertEquals("SELF_PERMISSION_CHANGE", code(() -> svc.setAccess(owner, 10L, 1L, role(Role.MEMBER))));
        assertEquals("SELF_PERMISSION_CHANGE", code(() -> svc.reset(owner, 10L, 1L)));
    }

    @Test
    void ownerPermissionsCannotBeTakenByAnyone() {
        t.member(2L, Role.ADMIN);
        t.grant(2L, MANAGE_ROLES);
        t.member(1L, Role.OWNER);
        Actor admin = new Actor(2L, false);

        assertEquals("OWNER_PROTECTED", code(() -> svc.setAccess(admin, 10L, 1L, perms())));
        assertEquals("OWNER_PROTECTED", code(() -> svc.reset(admin, 10L, 1L)));
        assertEquals("OWNER_PROTECTED", code(() -> svc.setAccess(new Actor(500L, true), 10L, 1L, role(Role.MEMBER))));
    }

    @Test
    void adminWithManageRolesCannotGrantAdminOrManageRoles() {
        t.member(2L, Role.ADMIN);
        t.grant(2L, MANAGE_ROLES, MANAGE_POSTS, MANAGE_MEMBERS);
        t.member(5L, Role.MEMBER);
        Actor admin = new Actor(2L, false);

        assertEquals("ESCALATION_DENIED", code(() -> svc.setAccess(admin, 10L, 5L, role(Role.ADMIN))));
        assertEquals("ESCALATION_DENIED", code(() -> svc.setAccess(admin, 10L, 5L, perms("MANAGE_ROLES"))));
    }

    @Test
    void adminCannotGiveWhatItDoesNotHave() {
        t.member(2L, Role.ADMIN);
        t.grant(2L, MANAGE_ROLES, MANAGE_POSTS);
        t.member(5L, Role.MEMBER);
        Actor admin = new Actor(2L, false);

        assertEquals("ESCALATION_DENIED", code(() -> svc.setAccess(admin, 10L, 5L, perms("MANAGE_EVENTS"))));
        assertEquals("ESCALATION_DENIED", code(() -> svc.setAccess(admin, 10L, 5L, role(Role.MODERATOR))));
        verify(t.grants, never()).save(any());
    }

    @Test
    void adminCanGiveSubsetOfOwnPermissionsToLowerRank() {
        t.member(2L, Role.ADMIN);
        t.grant(2L, MANAGE_ROLES, MANAGE_POSTS, MANAGE_MEMBERS);
        t.member(5L, Role.MEMBER);

        AccessView v = svc.setAccess(new Actor(2L, false), 10L, 5L, perms("MANAGE_POSTS"));

        assertEquals(Set.of(MANAGE_POSTS), v.permissions());
    }

    @Test
    void adminCannotTouchPeerAdminOrOwner() {
        t.member(2L, Role.ADMIN);
        t.grant(2L, MANAGE_ROLES, MANAGE_POSTS);
        t.member(3L, Role.ADMIN);
        Actor admin = new Actor(2L, false);

        assertEquals("ESCALATION_DENIED", code(() -> svc.setAccess(admin, 10L, 3L, perms())));
        assertEquals("ESCALATION_DENIED", code(() -> svc.reset(admin, 10L, 3L)));
    }

    @Test
    void ownerRoleCannotBeAssigned() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);

        assertEquals("INVALID_ROLE", code(() -> svc.setAccess(owner, 10L, 5L, role(Role.OWNER))));
    }

    @Test
    void invalidInputsAreRejected() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER);

        assertEquals("INVALID_PERMISSION", code(() -> svc.setAccess(owner, 10L, 5L, perms("FLY"))));
        assertEquals("INVALID_TEMPLATE", code(() -> svc.setAccess(owner, 10L, 5L, template("NOPE"))));
        assertEquals("VALIDATION_ERROR", code(() -> svc.setAccess(owner, 10L, 5L, new AccessRequest(null, null, null))));
    }

    @Test
    void nonMemberGets404NotDetails() {
        t.member(5L, Role.MEMBER);

        var e = ClubTestSupport.error(() -> svc.setAccess(new Actor(77L, false), 10L, 5L, role(Role.MODERATOR)));
        assertEquals(HttpStatus.NOT_FOUND, e.status());
        assertEquals("COMMUNITY_NOT_FOUND", e.code());
    }

    @Test
    void targetMustBeActiveMember() {
        t.member(1L, Role.OWNER);
        t.member(5L, Role.MEMBER, CommunityMember.Status.BANNED);

        assertEquals("NOT_MEMBER", code(() -> svc.setAccess(owner, 10L, 5L, role(Role.MODERATOR))));
        assertEquals("NOT_MEMBER", code(() -> svc.setAccess(owner, 10L, 99L, role(Role.MODERATOR))));
    }

    // ---- okuma ----

    @Test
    void viewIsLimitedToStaffAndSelf() {
        t.member(3L, Role.MEMBER);
        t.member(5L, Role.MEMBER);
        t.member(2L, Role.MODERATOR);

        assertEquals("FORBIDDEN", code(() -> svc.view(new Actor(3L, false), 10L, 5L)));
        assertEquals(Role.MEMBER, svc.view(new Actor(3L, false), 10L, 3L).role());
        assertEquals(Role.MEMBER, svc.view(new Actor(2L, false), 10L, 5L).role());
    }

    @Test
    void mineReturnsOwnPermissionsAndTemplatesAreListed() {
        t.member(5L, Role.MEMBER);
        t.grant(5L, MANAGE_POSTS);

        assertEquals(Set.of(MANAGE_POSTS), svc.mine(new Actor(5L, false), 10L).permissions());
        assertTrue(svc.templates().stream().anyMatch(x -> x.name().equals("EVENT_MANAGER")));
        assertTrue(svc.templates().stream().noneMatch(x -> x.permissions().contains(MANAGE_ROLES)));
        assertNull(svc.templates().stream().filter(x -> x.name().equals("MEMBER")).findFirst().get().permissions().stream()
                .findFirst().orElse(null));
    }
}
