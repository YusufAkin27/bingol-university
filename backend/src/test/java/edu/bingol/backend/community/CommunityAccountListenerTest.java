package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubMemberGrantRepository;
import edu.bingol.backend.media.MediaReferenceSource;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.profile.UserAccountDeletedEvent;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Hesap silme: sahipsiz kulup onleme (devir ya da kapatma) ve kulup gonderisi gorsellerinin temizligi. */
class CommunityAccountListenerTest {

    private static final long OWNER = 1L;
    private static final long CLUB = 10L;

    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final ClubMemberGrantRepository grants = mock(ClubMemberGrantRepository.class);
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final CommunityService service = mock(CommunityService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final CommunityPostMedia postMedia = mock(CommunityPostMedia.class);
    private final CommunityAccountListener listener = new CommunityAccountListener(communities, members, grants, audit,
            service, notifications, users, postMedia);

    private Community club;

    @BeforeEach
    void setUp() {
        club = new Community();
        club.setId(CLUB);
        club.setName("Satranc");
        club.setOwnerId(OWNER);
        club.setStatus(Community.Status.ACTIVE);
        when(communities.findByOwnerIdAndStatusIn(eq(OWNER), anyCollection())).thenReturn(List.of(club));
    }

    private CommunityMember member(long userId, Role role) {
        CommunityMember m = new CommunityMember();
        m.setCommunityId(CLUB);
        m.setUserId(userId);
        m.setRole(role);
        m.setStatus(CommunityMember.Status.ACTIVE);
        return m;
    }

    private void user(long id, UserStatus st) {
        User u = new User();
        u.setId(id);
        u.setStatus(st);
        when(users.findById(id)).thenReturn(Optional.of(u));
    }

    private void admins(CommunityMember... list) {
        when(members.findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(eq(CLUB),
                eq(CommunityMember.Status.ACTIVE), eq(List.of(Role.ADMIN)))).thenReturn(List.of(list));
        when(members.findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(eq(CLUB),
                eq(CommunityMember.Status.ACTIVE), eq(List.of(Role.MODERATOR)))).thenReturn(List.of());
    }

    @Test
    void ownershipGoesToOldestActiveAdminAndOldOwnerRowIsRemoved() {
        CommunityMember admin = member(5L, Role.ADMIN);
        CommunityMember oldOwner = member(OWNER, Role.OWNER);
        user(5L, UserStatus.ACTIVE);
        admins(admin);
        when(members.findByCommunityIdAndUserId(CLUB, 5L)).thenReturn(Optional.of(admin));
        when(members.findByCommunityIdAndUserId(CLUB, OWNER)).thenReturn(Optional.of(oldOwner));
        when(communities.countByOwnerIdAndStatusIn(eq(5L), anyCollection())).thenReturn(0L);

        assertEquals(1, listener.handleOwnedClubs(OWNER));

        assertEquals(Role.OWNER, admin.getRole());
        assertEquals(5L, club.getOwnerId());
        verify(members).delete(oldOwner);
        verify(audit).record(eq(CLUB), eq(null), eq(5L), eq(CommunityAccountListener.OWNER_AUTO_TRANSFERRED), any());
        verify(notifications).sendTemplated(eq(5L), eq(NotificationType.COMMUNITY),
                eq("notif.community.ownerAutoTransferred"), any(), eq("Satranc"));
        verify(service, never()).delete(any(), anyLong());
    }

    @Test
    void moderatorIsUsedWhenThereIsNoAdmin() {
        CommunityMember mod = member(6L, Role.MODERATOR);
        user(6L, UserStatus.ACTIVE);
        when(members.findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(eq(CLUB),
                eq(CommunityMember.Status.ACTIVE), eq(List.of(Role.ADMIN)))).thenReturn(List.of());
        when(members.findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(eq(CLUB),
                eq(CommunityMember.Status.ACTIVE), eq(List.of(Role.MODERATOR)))).thenReturn(List.of(mod));
        when(members.findByCommunityIdAndUserId(CLUB, 6L)).thenReturn(Optional.of(mod));
        when(members.findByCommunityIdAndUserId(CLUB, OWNER)).thenReturn(Optional.empty());

        assertEquals(1, listener.handleOwnedClubs(OWNER));
        assertEquals(6L, club.getOwnerId());
    }

    @Test
    void clubIsClosedWhenNobodyCanTakeOver() {
        // aday: askidaki yonetici ve zaten 3 kulubun sahibi olan moderator
        CommunityMember suspended = member(5L, Role.ADMIN);
        CommunityMember busy = member(6L, Role.MODERATOR);
        user(5L, UserStatus.SUSPENDED);
        user(6L, UserStatus.ACTIVE);
        when(members.findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(eq(CLUB),
                eq(CommunityMember.Status.ACTIVE), eq(List.of(Role.ADMIN)))).thenReturn(List.of(suspended));
        when(members.findByCommunityIdAndStatusAndRoleInOrderByJoinedAtAscIdAsc(eq(CLUB),
                eq(CommunityMember.Status.ACTIVE), eq(List.of(Role.MODERATOR)))).thenReturn(List.of(busy));
        when(communities.countByOwnerIdAndStatusIn(eq(6L), anyCollection())).thenReturn(3L);

        assertEquals(0, listener.handleOwnedClubs(OWNER));

        verify(service).delete(eq(new Actor(OWNER, true)), eq(CLUB));
        assertEquals(OWNER, club.getOwnerId());
    }

    @Test
    void accountDeletionAlsoReleasesPostImagesAndSurvivesFailures() {
        org.mockito.Mockito.doThrow(new IllegalStateException("x")).when(postMedia).releaseByAuthor(OWNER);
        when(communities.findByOwnerIdAndStatusIn(eq(OWNER), anyCollection())).thenReturn(List.of());

        listener.onAccountDeleted(new UserAccountDeletedEvent(OWNER, List.of())); // exception sizmaz

        verify(postMedia).releaseByAuthor(OWNER);
        verify(communities).findByOwnerIdAndStatusIn(eq(OWNER), anyCollection());
    }

    @Test
    void clubDeletionReleasesItsPostImages() {
        listener.onClubDeleted(new ClubDeletedEvent(CLUB));
        verify(postMedia).releaseByCommunity(CLUB);
    }

    // ---- CommunityPostMedia ----

    @Test
    void postImageIsClearedAndFileDeletedOnlyWhenUnreferenced() {
        CommunityPostRepository posts = mock(CommunityPostRepository.class);
        FileStorage storage = mock(FileStorage.class);
        MediaReferenceSource used = url -> url.endsWith("shared.jpg");
        CommunityPostMedia media = new CommunityPostMedia(posts, storage, List.of(used));

        CommunityPost own = new CommunityPost();
        own.setId(1L);
        own.setImageUrl("/files/posts/own.jpg");
        CommunityPost shared = new CommunityPost();
        shared.setId(2L);
        shared.setImageUrl("/files/posts/shared.jpg");
        CommunityPost none = new CommunityPost();
        none.setId(3L);

        media.release(List.of(own, shared, none));

        assertNull(own.getImageUrl());
        assertNull(shared.getImageUrl());
        verify(storage).delete("/files/posts/own.jpg");
        verify(storage, never()).delete("/files/posts/shared.jpg");
        verify(posts).saveAndFlush(own);
        verify(posts, never()).saveAndFlush(none);
    }
}
