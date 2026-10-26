package edu.bingol.backend.community.permissions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityPost;
import edu.bingol.backend.community.CommunityPostRepository;
import edu.bingol.backend.community.CommunityPostService;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Gonderi silme/sabitleme MANAGE_POSTS'a baglidir; yazar kendi gonderisini her zaman silebilir. */
class ClubPostPermissionTest {

    private final CommunityService communities = mock(CommunityService.class);
    private final CommunityPostRepository posts = mock(CommunityPostRepository.class);
    private final CommunityPostService svc = new CommunityPostService(communities, posts,
            mock(CommunityMemberRepository.class), mock(BlockService.class), mock(NotificationService.class),
            mock(FileStorage.class));
    private final Actor user = new Actor(1L, false);

    private CommunityPost post(long id, long author) {
        CommunityPost p = new CommunityPost();
        p.setId(id);
        p.setCommunityId(10L);
        p.setAuthorId(author);
        p.setContent("x");
        when(posts.findByIdAndCommunityIdAndDeletedFalse(id, 10L)).thenReturn(Optional.of(p));
        return p;
    }

    @Test
    void postManagerGrantAllowsDeletingOthersPosts() {
        when(communities.load(10L)).thenReturn(new Community());
        when(communities.can(user, 10L, ClubPermission.MANAGE_POSTS)).thenReturn(true);
        CommunityPost other = post(6L, 2L);

        svc.delete(user, 10L, 6L);

        assertTrue(other.isDeleted());
    }

    @Test
    void withoutManagePostsOthersPostsStay() {
        when(communities.load(10L)).thenReturn(new Community());
        when(communities.can(user, 10L, ClubPermission.MANAGE_POSTS)).thenReturn(false);
        CommunityPost other = post(6L, 2L);

        assertEquals(HttpStatus.FORBIDDEN, assertThrows(ApiException.class, () -> svc.delete(user, 10L, 6L)).status());
        assertFalse(other.isDeleted());
    }

    @Test
    void authorDeletesOwnPostWithoutAnyPermission() {
        when(communities.load(10L)).thenReturn(new Community());
        CommunityPost own = post(5L, 1L);

        svc.delete(user, 10L, 5L);

        assertTrue(own.isDeleted());
    }

    @Test
    void pinningRequiresManagePosts() {
        when(communities.load(10L)).thenReturn(new Community());
        doThrow(new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "yetki yok"))
                .when(communities).require(eq(user), eq(10L), eq(ClubPermission.MANAGE_POSTS));
        CommunityPost p = post(5L, 2L);

        assertEquals("FORBIDDEN", assertThrows(ApiException.class, () -> svc.pin(user, 10L, 5L, true)).code());
        assertFalse(p.isPinned());
        verify(posts, never()).save(any());
    }
}
