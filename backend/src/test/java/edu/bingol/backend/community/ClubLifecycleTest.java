package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Kulup kurma (auto-approve), silme ve ayrilma kurallari. */
class ClubLifecycleTest {

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final ClubExtrasHooks hooks = mock(ClubExtrasHooks.class);
    private final MediaService media = mock(MediaService.class);
    private final CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
            mock(BlockService.class), notifications, media,
            new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class), hooks);

    private final Actor owner = new Actor(1L, false);
    private final Actor other = new Actor(2L, false);

    private static Community club(Community.Status st) {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(1L);
        c.setStatus(st);
        c.setCoverUrl("/files/kapak.jpg");
        return c;
    }

    @Test
    void autoApproveCreatesActiveClubAndRoom() {
        svc.setAutoApprove(true);
        when(communities.saveAndFlush(any())).thenAnswer(i -> {
            Community c = i.getArgument(0);
            c.setId(10L);
            return c;
        });

        Community c = svc.create(owner, new CreateCommunityRequest("Yazılım Kulübü", null, null, null, null));

        assertEquals(Community.Status.ACTIVE, c.getStatus());
        verify(hooks).onCommunityActivated(c);
    }

    @Test
    void approvalFlowStillWorksWhenAutoApproveOff() {
        svc.setAutoApprove(false);
        when(communities.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));

        Community c = svc.create(owner, new CreateCommunityRequest("Yazılım Kulübü", null, null, null, null));

        assertEquals(Community.Status.PENDING_REVIEW, c.getStatus());
        verify(hooks, never()).onCommunityActivated(any());
    }

    @Test
    void ownerDeletesClub() {
        Community c = club(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        when(members.userIdsByStatus(eq(10L), eq(CommunityMember.Status.ACTIVE), any())).thenReturn(List.of(1L, 3L, 4L));

        svc.delete(owner, 10L);

        assertEquals(Community.Status.DELETED, c.getStatus());
        assertNull(c.getCoverUrl());
        verify(media).release("/files/kapak.jpg");
        verify(hooks).onCommunityDeleted(c);
        // silen kisi haric uyelere bildirim
        verify(notifications).sendTemplated(eq(3L), eq(NotificationType.COMMUNITY), eq("notif.community.deleted"), any(), anyString());
        verify(notifications).sendTemplated(eq(4L), eq(NotificationType.COMMUNITY), eq("notif.community.deleted"), any(), anyString());
        verify(notifications, never()).sendTemplated(eq(1L), any(), anyString(), any(), anyString());
    }

    @Test
    void nonOwnerCannotDelete() {
        Community c = club(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));

        ApiException e = assertThrows(ApiException.class, () -> svc.delete(other, 10L));

        assertEquals(HttpStatus.FORBIDDEN, e.status());
        assertEquals(Community.Status.ACTIVE, c.getStatus());
        verify(hooks, never()).onCommunityDeleted(any());
    }

    @Test
    void adminCanDeleteAnyClub() {
        Community c = club(Community.Status.ACTIVE);
        when(communities.findById(10L)).thenReturn(Optional.of(c));

        svc.delete(new Actor(500L, true), 10L);

        assertEquals(Community.Status.DELETED, c.getStatus());
    }

    @Test
    void deletedClubIsNotFoundEvenForOwner() {
        when(communities.findById(10L)).thenReturn(Optional.of(club(Community.Status.DELETED)));

        assertEquals("COMMUNITY_NOT_FOUND", assertThrows(ApiException.class, () -> svc.load(10L)).code());
        assertEquals("COMMUNITY_NOT_FOUND", assertThrows(ApiException.class, () -> svc.delete(owner, 10L)).code());
        assertEquals("COMMUNITY_NOT_FOUND", assertThrows(ApiException.class, () -> svc.join(other, 10L)).code());
    }

    @Test
    void memberLeavingDropsRoomAccess() {
        when(members.findByCommunityIdAndUserId(10L, 2L))
                .thenReturn(Optional.of(new CommunityMember(10L, 2L, Role.MEMBER, CommunityMember.Status.ACTIVE)));

        svc.leave(other, 10L);

        verify(hooks).onMemberGone(10L, 2L); // sohbet odasi + etkinlik odalari buradan dusurulur
    }

    @Test
    void ownerCannotLeaveClub() {
        when(members.findByCommunityIdAndUserId(10L, 1L))
                .thenReturn(Optional.of(new CommunityMember(10L, 1L, Role.OWNER, CommunityMember.Status.ACTIVE)));

        ApiException e = assertThrows(ApiException.class, () -> svc.leave(owner, 10L));

        assertEquals("OWNER_CANNOT_LEAVE", e.code());
        verify(hooks, never()).onMemberGone(any(), any());
    }
}
