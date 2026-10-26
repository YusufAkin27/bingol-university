package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.media.StoredImage;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.web.multipart.MultipartFile;

/** Uyelik/yasam dongusu degisimleri sohbet odasi ve basvuru yanitlariyla senkron kalir (T15). */
class CommunityRoomSyncTest {

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final MediaService media = mock(MediaService.class);
    private final ClubExtrasHooks hooks = mock(ClubExtrasHooks.class);
    private final CommunityService svc = new CommunityService(communities, members, mock(UserRepository.class),
            mock(BlockService.class), mock(NotificationService.class), media,
            new ClubPermissions(members, mock(ClubMemberGrantRepository.class)), mock(ClubAuditService.class), hooks);

    private final Actor user = new Actor(1L, false);
    private final Actor owner = new Actor(99L, false);

    private Community club(Community.JoinPolicy policy, Community.Visibility vis) {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(99L);
        c.setStatus(Community.Status.ACTIVE);
        c.setJoinPolicy(policy);
        c.setVisibility(vis);
        when(communities.findById(10L)).thenReturn(Optional.of(c));
        return c;
    }

    private void member(long uid, Role role, CommunityMember.Status st) {
        when(members.findByCommunityIdAndUserId(10L, uid)).thenReturn(Optional.of(new CommunityMember(10L, uid, role, st)));
    }

    @Test
    void openJoinAddsToRoomButApprovalJoinDoesNot() {
        club(Community.JoinPolicy.OPEN, Community.Visibility.PUBLIC);
        svc.join(user, 10L);
        verify(hooks).onMemberActivated(10L, 1L);

        club(Community.JoinPolicy.APPROVAL, Community.Visibility.PUBLIC);
        svc.join(new Actor(2L, false), 10L);
        verify(hooks, never()).onMemberActivated(10L, 2L);
    }

    @Test
    void privateClubJoinDoesNotEnterRoomUntilApproved() {
        club(Community.JoinPolicy.OPEN, Community.Visibility.PRIVATE);

        svc.join(user, 10L);

        verify(hooks, never()).onMemberActivated(anyLong(), anyLong());
    }

    @Test
    void leaveRemovesFromRoom() {
        member(1L, Role.MEMBER, CommunityMember.Status.ACTIVE);

        svc.leave(user, 10L);

        verify(hooks).onMemberGone(10L, 1L);
    }

    @Test
    void approveAddsAndRejectRemovesAndDropsAnswers() {
        club(Community.JoinPolicy.APPROVAL, Community.Visibility.PUBLIC);
        member(99L, Role.OWNER, CommunityMember.Status.ACTIVE);
        member(5L, Role.MEMBER, CommunityMember.Status.PENDING);
        svc.decide(owner, 10L, 5L, true);
        verify(hooks).onMemberActivated(10L, 5L);

        member(6L, Role.MEMBER, CommunityMember.Status.PENDING);
        svc.decide(owner, 10L, 6L, false);
        verify(hooks).onMemberGone(10L, 6L);
        verify(hooks, never()).onMemberActivated(10L, 6L);
    }

    @Test
    void removeAndBanTakeUserOutOfRoom() {
        club(Community.JoinPolicy.OPEN, Community.Visibility.PUBLIC);
        member(99L, Role.OWNER, CommunityMember.Status.ACTIVE);
        member(5L, Role.MEMBER, CommunityMember.Status.ACTIVE);
        svc.remove(owner, 10L, 5L, true);
        member(6L, Role.MEMBER, CommunityMember.Status.ACTIVE);
        svc.remove(owner, 10L, 6L, false);

        verify(hooks).onMemberGone(10L, 5L);
        verify(hooks).onMemberGone(10L, 6L);
    }

    @Test
    void approvalOfClubCreatesRoomRejectionDoesNot() {
        Community c = club(Community.JoinPolicy.OPEN, Community.Visibility.PUBLIC);
        c.setStatus(Community.Status.PENDING_REVIEW);

        svc.review(10L, true, null);
        verify(hooks).onCommunityActivated(c);

        Community d = club(Community.JoinPolicy.OPEN, Community.Visibility.PUBLIC);
        d.setStatus(Community.Status.PENDING_REVIEW);
        svc.review(10L, false, "uygun degil");
        verify(hooks, org.mockito.Mockito.times(1)).onCommunityActivated(any());
    }

    @Test
    void renameRenamesRoomOnlyWhenNameChanged() {
        Community c = club(Community.JoinPolicy.OPEN, Community.Visibility.PUBLIC);
        member(99L, Role.OWNER, CommunityMember.Status.ACTIVE);

        svc.update(owner, 10L, new edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest(
                "Kulup", "yeni aciklama", null, null, null));
        verify(hooks, never()).onRenamed(any());

        svc.update(owner, 10L, new edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest(
                "Yeni Ad", null, null, null, null));
        verify(hooks).onRenamed(c);
    }

    @Test
    void coverAndLogoUseMediaPipelineAndReleaseOldFile() {
        Community c = club(Community.JoinPolicy.OPEN, Community.Visibility.PUBLIC);
        member(99L, Role.OWNER, CommunityMember.Status.ACTIVE);
        c.setCoverUrl("/files/covers/old.jpg");
        c.setLogoUrl("/files/avatars/oldlogo.jpg");
        MultipartFile f = mock(MultipartFile.class);
        when(media.storeImage(f, edu.bingol.backend.media.ImageKind.COVER))
                .thenReturn(new StoredImage("/files/covers/new.jpg", "/files/covers/new-t.jpg", 1, 1, 1, "image/jpeg"));
        when(media.storeImage(f, edu.bingol.backend.media.ImageKind.AVATAR))
                .thenReturn(new StoredImage("/files/avatars/newlogo.jpg", "/files/avatars/newlogo-t.jpg", 1, 1, 1, "image/jpeg"));

        svc.setCover(owner, 10L, f);
        svc.setLogo(owner, 10L, f);

        assertEquals("/files/covers/new.jpg", c.getCoverUrl());
        assertEquals("/files/avatars/newlogo.jpg", c.getLogoUrl());
        verify(media).release("/files/covers/old.jpg");
        verify(media).release("/files/avatars/oldlogo.jpg");

        svc.removeLogo(owner, 10L);
        assertEquals(null, c.getLogoUrl());
        verify(media).release("/files/avatars/newlogo.jpg");
    }

    @Test
    void logoRequiresInfoEditPermission() {
        club(Community.JoinPolicy.OPEN, Community.Visibility.PUBLIC);
        member(1L, Role.MEMBER, CommunityMember.Status.ACTIVE);
        MultipartFile f = mock(MultipartFile.class);

        org.junit.jupiter.api.Assertions.assertThrows(edu.bingol.backend.common.ApiException.class,
                () -> svc.setLogo(user, 10L, f));
        verify(media, never()).storeImage(any(), any());
    }
}
