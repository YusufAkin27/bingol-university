package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class CommunityServiceTest {

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
            mock(BlockService.class), notifications, mock(FileStorage.class));

    private final Actor user = new Actor(1L, false);

    private static Community community(Community.JoinPolicy policy) {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(99L);
        c.setStatus(Community.Status.ACTIVE);
        c.setJoinPolicy(policy);
        return c;
    }

    private static CommunityMember member(Long userId, Role role, CommunityMember.Status st) {
        return new CommunityMember(10L, userId, role, st);
    }

    private void stubMember(Long userId, Role role, CommunityMember.Status st) {
        when(members.findByCommunityIdAndUserId(10L, userId)).thenReturn(Optional.of(member(userId, role, st)));
    }

    private static ApiException error(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    // ---- olusturma ----

    @Test
    void createRejectsFourthOwnedCommunity() {
        when(communities.countByOwnerIdAndStatusIn(eq(1L), any())).thenReturn(3L);

        ApiException e = error(() -> svc.create(user, new CreateCommunityRequest("Yeni Kulup", null, null, null, null)));

        assertEquals("COMMUNITY_LIMIT", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
        verify(communities, never()).saveAndFlush(any());
    }

    @Test
    void createMakesPendingCommunityWithOwnerMembership() {
        when(communities.countByOwnerIdAndStatusIn(eq(1L), any())).thenReturn(2L);
        when(communities.saveAndFlush(any())).thenAnswer(i -> {
            Community c = i.getArgument(0);
            c.setId(10L);
            return c;
        });

        Community c = svc.create(user, new CreateCommunityRequest("Yazılım Kulübü", "aciklama", "teknoloji", null, null));

        assertEquals(Community.Status.PENDING_REVIEW, c.getStatus());
        assertEquals("yazilim-kulubu", c.getSlug());
        assertEquals(1L, c.getOwnerId());
        verify(members).save(org.mockito.ArgumentMatchers.argThat(m ->
                m.getRole() == Role.OWNER && m.isActive() && m.getUserId().equals(1L)));
    }

    @Test
    void slugGetsNumericSuffixOnCollision() {
        when(communities.existsBySlug("yazilim-kulubu")).thenReturn(true);
        when(communities.existsBySlug("yazilim-kulubu-2")).thenReturn(true);

        assertEquals("yazilim-kulubu-3", svc.uniqueSlug("Yazılım Kulübü"));
    }

    // ---- katilma / ayrilma ----

    @Test
    void joiningOpenCommunityMakesActiveMember() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        when(members.findByCommunityIdAndUserId(10L, 1L)).thenReturn(Optional.empty());

        assertEquals("ACTIVE", svc.join(user, 10L));
        verify(notifications, never()).send(anyLong(), any(), any(), any(), any());
    }

    @Test
    void joiningApprovalCommunityIsPendingAndNotifiesModerators() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.APPROVAL)));
        when(members.findByCommunityIdAndUserId(10L, 1L)).thenReturn(Optional.empty());
        when(members.moderatorIds(eq(10L), any(), any())).thenReturn(List.of(99L));

        assertEquals("PENDING", svc.join(user, 10L));
        verify(notifications).send(eq(99L), eq(NotificationType.COMMUNITY), any(), any(), any());
    }

    @Test
    void bannedUserCannotRejoin() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.MEMBER, CommunityMember.Status.BANNED);

        ApiException e = error(() -> svc.join(user, 10L));

        assertEquals("BANNED", e.code());
        assertEquals(HttpStatus.FORBIDDEN, e.status());
    }

    @Test
    void cannotJoinTwice() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.MEMBER, CommunityMember.Status.ACTIVE);

        assertEquals("ALREADY_MEMBER", error(() -> svc.join(user, 10L)).code());
    }

    @Test
    void cannotJoinInactiveCommunity() {
        Community c = community(Community.JoinPolicy.OPEN);
        c.setStatus(Community.Status.PENDING_REVIEW);
        when(communities.findById(10L)).thenReturn(Optional.of(c));

        assertEquals(HttpStatus.NOT_FOUND, error(() -> svc.join(user, 10L)).status());
    }

    @Test
    void ownerCannotLeave() {
        stubMember(1L, Role.OWNER, CommunityMember.Status.ACTIVE);

        assertEquals("OWNER_CANNOT_LEAVE", error(() -> svc.leave(user, 10L)).code());
        verify(members, never()).delete(any());
    }

    @Test
    void memberCanLeave() {
        stubMember(1L, Role.MEMBER, CommunityMember.Status.ACTIVE);

        svc.leave(user, 10L);

        verify(members).delete(any());
    }

    @Test
    void bannedUserCannotLeaveToClearBan() {
        stubMember(1L, Role.MEMBER, CommunityMember.Status.BANNED);

        assertEquals("BANNED", error(() -> svc.leave(user, 10L)).code());
        verify(members, never()).delete(any());
    }

    // ---- roller ----

    @Test
    void onlyOwnerCanAssignRoles() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.MODERATOR, CommunityMember.Status.ACTIVE);

        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.setRole(user, 10L, 5L, Role.MODERATOR)).status());
    }

    @Test
    void ownerAssignsModerator() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.OWNER, CommunityMember.Status.ACTIVE);
        CommunityMember target = member(5L, Role.MEMBER, CommunityMember.Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 5L)).thenReturn(Optional.of(target));

        svc.setRole(user, 10L, 5L, Role.MODERATOR);

        assertEquals(Role.MODERATOR, target.getRole());
    }

    @Test
    void ownerRoleCannotBeAssigned() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.OWNER, CommunityMember.Status.ACTIVE);

        assertEquals("INVALID_ROLE", error(() -> svc.setRole(user, 10L, 5L, Role.OWNER)).code());
    }

    @Test
    void moderatorBansMemberButNotModerator() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.MODERATOR, CommunityMember.Status.ACTIVE);
        CommunityMember victim = member(5L, Role.MEMBER, CommunityMember.Status.ACTIVE);
        CommunityMember otherMod = member(6L, Role.MODERATOR, CommunityMember.Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 5L)).thenReturn(Optional.of(victim));
        when(members.findByCommunityIdAndUserId(10L, 6L)).thenReturn(Optional.of(otherMod));

        svc.remove(user, 10L, 5L, true);
        assertEquals(CommunityMember.Status.BANNED, victim.getStatus());

        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.remove(user, 10L, 6L, false)).status());
    }

    @Test
    void plainMemberCannotRemoveAnyone() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.MEMBER, CommunityMember.Status.ACTIVE);

        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.remove(user, 10L, 5L, false)).status());
    }

    @Test
    void ownerCannotBeRemoved() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        stubMember(1L, Role.MODERATOR, CommunityMember.Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 99L))
                .thenReturn(Optional.of(member(99L, Role.OWNER, CommunityMember.Status.ACTIVE)));

        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.remove(user, 10L, 99L, true)).status());
    }

    @Test
    void approvingRequestActivatesMemberAndNotifies() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.APPROVAL)));
        stubMember(1L, Role.MODERATOR, CommunityMember.Status.ACTIVE);
        CommunityMember pending = member(5L, Role.MEMBER, CommunityMember.Status.PENDING);
        when(members.findByCommunityIdAndUserId(10L, 5L)).thenReturn(Optional.of(pending));

        svc.decide(user, 10L, 5L, true);

        assertEquals(CommunityMember.Status.ACTIVE, pending.getStatus());
        verify(notifications).send(eq(5L), eq(NotificationType.COMMUNITY), any(), any(), any());
    }

    @Test
    void adminActsAsOwnerWithoutMembership() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));
        CommunityMember target = member(5L, Role.MEMBER, CommunityMember.Status.ACTIVE);
        when(members.findByCommunityIdAndUserId(10L, 5L)).thenReturn(Optional.of(target));

        svc.setRole(new Actor(500L, true), 10L, 5L, Role.MODERATOR);

        assertEquals(Role.MODERATOR, target.getRole());
    }

    // ---- admin onayi ----

    @Test
    void approvalActivatesPendingCommunity() {
        Community c = community(Community.JoinPolicy.OPEN);
        c.setStatus(Community.Status.PENDING_REVIEW);
        when(communities.findById(10L)).thenReturn(Optional.of(c));

        svc.review(10L, true, null);

        assertEquals(Community.Status.ACTIVE, c.getStatus());
        verify(notifications).send(eq(99L), eq(NotificationType.COMMUNITY), any(), any(), any());
    }

    @Test
    void reviewRejectsNonPendingCommunity() {
        when(communities.findById(10L)).thenReturn(Optional.of(community(Community.JoinPolicy.OPEN)));

        assertEquals("NOT_PENDING", error(() -> svc.review(10L, true, null)).code());
    }
}
