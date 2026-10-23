package edu.bingol.backend.community;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.dto.CommunityDtos.CreatePostRequest;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class CommunityPostServiceTest {

    private final CommunityService communities = mock(CommunityService.class);
    private final CommunityPostRepository posts = mock(CommunityPostRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final CommunityPostService svc = new CommunityPostService(communities, posts, members, blocks,
            notifications, mock(FileStorage.class));

    private final Actor user = new Actor(1L, false);

    private Community active() {
        Community c = new Community();
        c.setId(10L);
        c.setName("Kulup");
        c.setOwnerId(99L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.loadVisible(any(), eq(10L))).thenReturn(c);
        when(communities.load(10L)).thenReturn(c);
        return c;
    }

    private static CommunityPost post(long id, long author) {
        CommunityPost p = new CommunityPost();
        p.setId(id);
        p.setCommunityId(10L);
        p.setAuthorId(author);
        p.setContent("merhaba");
        return p;
    }

    @Test
    void nonMemberCannotPost() {
        active();
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class, () -> svc.create(user, 10L, new CreatePostRequest("selam", null)));

        assertEquals("NOT_MEMBER", e.code());
        verify(posts, never()).save(any());
    }

    @Test
    void foreignImageUrlIsRejected() {
        active();
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.of(Role.MEMBER));

        ApiException e = assertThrows(ApiException.class,
                () -> svc.create(user, 10L, new CreatePostRequest("selam", "https://evil.example/x.png")));

        assertEquals("INVALID_IMAGE_URL", e.code());
    }

    @Test
    void memberPostsAndOtherMembersAreNotifiedExceptAuthorAndBlocked() {
        Community c = active();
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.of(Role.MEMBER));
        when(communities.effectiveRole(any(), eq(c))).thenReturn(Role.MEMBER);
        when(communities.usersById(any())).thenReturn(Map.of());
        when(posts.save(any())).thenAnswer(i -> {
            CommunityPost p = i.getArgument(0);
            p.setId(7L);
            return p;
        });
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(3L));
        when(members.userIdsByStatus(eq(10L), any(), any())).thenReturn(List.of(1L, 2L, 3L));

        svc.create(user, 10L, new CreatePostRequest("selam", "/files/posts/a.png"));

        verify(notifications).send(eq(2L), eq(NotificationType.COMMUNITY), any(), any(), any());
        verify(notifications, never()).send(eq(1L), any(), any(), any(), any());
        verify(notifications, never()).send(eq(3L), any(), any(), any(), any());
    }

    @Test
    void strangerCannotDeleteOthersPost() {
        Community c = active();
        when(posts.findByIdAndCommunityIdAndDeletedFalse(5L, 10L)).thenReturn(Optional.of(post(5L, 2L)));
        when(communities.effectiveRole(any(), eq(c))).thenReturn(Role.MEMBER);

        assertEquals(HttpStatus.FORBIDDEN, assertThrows(ApiException.class, () -> svc.delete(user, 10L, 5L)).status());
    }

    @Test
    void authorAndModeratorCanDelete() {
        Community c = active();
        CommunityPost own = post(5L, 1L);
        when(posts.findByIdAndCommunityIdAndDeletedFalse(5L, 10L)).thenReturn(Optional.of(own));
        when(communities.effectiveRole(any(), eq(c))).thenReturn(Role.MEMBER);
        svc.delete(user, 10L, 5L);
        assertTrue(own.isDeleted());

        CommunityPost other = post(6L, 2L);
        when(posts.findByIdAndCommunityIdAndDeletedFalse(6L, 10L)).thenReturn(Optional.of(other));
        when(communities.effectiveRole(any(), eq(c))).thenReturn(Role.MODERATOR);
        svc.delete(user, 10L, 6L);
        assertTrue(other.isDeleted());
    }

    @Test
    void pinLimitIsEnforced() {
        active();
        when(posts.findByIdAndCommunityIdAndDeletedFalse(5L, 10L)).thenReturn(Optional.of(post(5L, 2L)));
        when(posts.countByCommunityIdAndPinnedTrueAndDeletedFalse(10L)).thenReturn(3L);

        assertEquals("PIN_LIMIT", assertThrows(ApiException.class, () -> svc.pin(user, 10L, 5L, true)).code());
    }
}
