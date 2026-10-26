package edu.bingol.backend.community.permissions;

import static edu.bingol.backend.community.permissions.ClubPermission.EDIT_INFO;
import static edu.bingol.backend.community.permissions.ClubPermission.INVITE;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_EVENTS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_MEMBERS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_POSTS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_ROLES;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Yetki matrisi: her konum x her yetki. Geriye uyumluluk: grant kaydi yoksa eski rol davranisi. */
class ClubPermissionsTest {

    private final ClubTestSupport t = new ClubTestSupport();
    private final Actor user = new Actor(1L, false);

    private static Set<ClubPermission> set(ClubPermission... p) {
        return p.length == 0 ? EnumSet.noneOf(ClubPermission.class) : EnumSet.copyOf(List.of(p));
    }

    private Set<ClubPermission> effective(Actor a) {
        return t.permissions.standing(a, 10L).map(ClubPermissions.Standing::permissions)
                .orElse(EnumSet.noneOf(ClubPermission.class));
    }

    @Test
    void memberHasNoPermissions() {
        t.member(1L, Role.MEMBER);
        assertEquals(set(), effective(user));
    }

    @Test
    void legacyModeratorKeepsEverythingExceptManageRoles() {
        t.member(1L, Role.MODERATOR);
        assertEquals(set(MANAGE_MEMBERS, MANAGE_POSTS, MANAGE_EVENTS, EDIT_INFO, INVITE), effective(user));
        assertFalse(t.permissions.has(user, 10L, MANAGE_ROLES));
    }

    @Test
    void adminDefaultsExcludeManageRoles() {
        t.member(1L, Role.ADMIN);
        assertEquals(set(MANAGE_MEMBERS, MANAGE_POSTS, MANAGE_EVENTS, EDIT_INFO, INVITE), effective(user));
    }

    @Test
    void ownerHasAllPermissions() {
        t.member(1L, Role.OWNER);
        assertEquals(ClubPermission.all(), effective(user));
    }

    @Test
    void systemAdminHasAllWithoutMembership() {
        assertEquals(ClubPermission.all(), effective(new Actor(500L, true)));
    }

    @Test
    void nonMemberAndPendingAndBannedHaveNothing() {
        assertTrue(t.permissions.standing(user, 10L).isEmpty());
        t.member(1L, Role.MODERATOR, CommunityMember.Status.PENDING);
        assertTrue(t.permissions.standing(user, 10L).isEmpty());
        t.member(1L, Role.MODERATOR, CommunityMember.Status.BANNED);
        assertTrue(t.permissions.standing(user, 10L).isEmpty());
    }

    @Test
    void grantReplacesRoleDefaultsBothWays() {
        // Uye + ozel yetki
        t.member(1L, Role.MEMBER);
        t.grant(1L, MANAGE_POSTS);
        assertEquals(set(MANAGE_POSTS), effective(user));
        // Moderator'un yetkisi kisitlanabilir
        t.member(2L, Role.MODERATOR);
        t.grant(2L, INVITE);
        assertEquals(set(INVITE), effective(new Actor(2L, false)));
    }

    @Test
    void ownerIgnoresGrantRows() {
        t.member(1L, Role.OWNER);
        t.grant(1L);
        assertEquals(ClubPermission.all(), effective(user));
    }

    @Test
    void permissionMatrixForAllPositions() {
        record Case(String name, Role role, ClubPermission[] grant, Set<ClubPermission> expected) { }
        List<Case> cases = List.of(
                new Case("member", Role.MEMBER, null, set()),
                new Case("moderator", Role.MODERATOR, null, set(MANAGE_MEMBERS, MANAGE_POSTS, MANAGE_EVENTS, EDIT_INFO, INVITE)),
                new Case("postManager", Role.MEMBER, new ClubPermission[] {MANAGE_POSTS}, set(MANAGE_POSTS)),
                new Case("eventManager", Role.MEMBER, new ClubPermission[] {MANAGE_EVENTS}, set(MANAGE_EVENTS)),
                new Case("memberManager", Role.MEMBER, new ClubPermission[] {MANAGE_MEMBERS, INVITE}, set(MANAGE_MEMBERS, INVITE)),
                new Case("adminWithRoles", Role.ADMIN, new ClubPermission[] {MANAGE_MEMBERS, MANAGE_ROLES}, set(MANAGE_MEMBERS, MANAGE_ROLES)),
                new Case("owner", Role.OWNER, null, ClubPermission.all()));
        long uid = 20;
        for (Case c : cases) {
            t.member(uid, c.role());
            if (c.grant() != null) {
                t.grant(uid, c.grant());
            }
            for (ClubPermission p : ClubPermission.values()) {
                assertEquals(c.expected().contains(p), t.permissions.has(new Actor(uid, false), 10L, p),
                        c.name() + " / " + p);
            }
            uid++;
        }
    }

    @Test
    void requireThrows403ForMissingPermission() {
        t.member(1L, Role.MEMBER);
        var e = ClubTestSupport.error(() -> t.permissions.require(user, 10L, MANAGE_POSTS));
        assertEquals(HttpStatus.FORBIDDEN, e.status());
        assertEquals("FORBIDDEN", e.code());
    }

    @Test
    void requireAnyPermissionRejectsPlainMembers() {
        t.member(1L, Role.MEMBER);
        assertEquals(HttpStatus.FORBIDDEN, ClubTestSupport.error(() -> t.permissions.requireAnyPermission(user, 10L)).status());
        t.grant(1L, INVITE);
        assertEquals(set(INVITE), t.permissions.requireAnyPermission(user, 10L).permissions());
    }

    @Test
    void ranksOrderRolesAndCustomMembers() {
        int member = ClubPermissions.rank(Role.MEMBER, set());
        int customMember = ClubPermissions.rank(Role.MEMBER, set(MANAGE_POSTS));
        int mod = ClubPermissions.rank(Role.MODERATOR, set());
        int admin = ClubPermissions.rank(Role.ADMIN, set());
        int owner = ClubPermissions.rank(Role.OWNER, set());
        assertTrue(member < customMember && customMember < mod && mod < admin && admin < owner);
    }

    @Test
    void holdersListsModeratorsAndGrantedMembersButNotRestrictedOnes() {
        when(t.members.moderatorIds(eq(10L), any(), any())).thenReturn(List.of(2L, 3L));
        t.member(2L, Role.MODERATOR);
        t.member(3L, Role.MODERATOR);
        ClubMemberGrant g3 = t.grant(3L, INVITE); // moderator ama MANAGE_MEMBERS kisitlanmis
        t.member(4L, Role.MEMBER);
        ClubMemberGrant g4 = t.grant(4L, MANAGE_MEMBERS);
        when(t.grants.findByCommunityId(10L)).thenReturn(List.of(g3, g4));

        List<Long> holders = t.permissions.holders(10L, MANAGE_MEMBERS);

        assertEquals(Set.of(2L, 4L), Set.copyOf(holders));
    }
}
