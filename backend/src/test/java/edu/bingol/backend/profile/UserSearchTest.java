package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.dto.ProfileDtos.UserSearchResult;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class UserSearchTest {

    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final PublicProfileMapper mapper = mock(PublicProfileMapper.class);
    private final ProfileService service = new ProfileService(users, blocks, null, null, null, null, mapper, null,
            null, null, null, mock(AccountDataPurger.class), null);

    private static List<User> rows(int n) {
        List<User> l = new ArrayList<>();
        for (long i = 1; i <= n; i++) {
            User u = new User();
            u.setId(i);
            l.add(u);
        }
        return l;
    }

    @SuppressWarnings("unchecked")
    private void echoMapper() {
        when(mapper.mapAll(any(), any())).thenAnswer(inv -> ((List<User>) inv.getArgument(1)).stream()
                .map(u -> new PublicProfile(u.getId(), null, null, null, null, null, null, null)).toList());
    }

    @Test
    void returnsNextCursorWhenMoreRowsExist() {
        echoMapper();
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(users.searchByName(any(), any(), eq(3), eq(0))).thenReturn(rows(3));

        UserSearchResult r = service.search(1L, "ab", 2, null);

        assertEquals(2, r.items().size());
        assertEquals(2L, r.nextCursor());
    }

    @Test
    void lastPageHasNoCursorAndExcludesSelfAndBlocked() {
        echoMapper();
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(9L));
        when(users.searchByName(any(), any(), anyInt(), eq(2))).thenReturn(rows(1));

        UserSearchResult r = service.search(1L, "ab", 2, 2L);

        assertNull(r.nextCursor());
        @SuppressWarnings("unchecked")
        ArgumentCaptor<java.util.Collection<Long>> ex = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(users).searchByName(any(), ex.capture(), anyInt(), eq(2));
        assertEquals(true, ex.getValue().containsAll(Set.of(1L, 9L)));
    }

    @Test
    void escapesLikeWildcards() {
        echoMapper();
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(users.searchByName(any(), any(), anyInt(), anyInt())).thenReturn(List.of());

        service.search(1L, "50%_a", 20, null);

        verify(users).searchByName(eq("50\\%\\_a"), any(), anyInt(), eq(0));
    }

    @Test
    void rejectsShortQueryAndBadCursor() {
        assertEquals("QUERY_TOO_SHORT", assertThrows(ApiException.class, () -> service.search(1L, " a ", 20, null)).code());
        assertThrows(ApiException.class, () -> service.search(1L, "ab", 20, -1L));
        assertThrows(ApiException.class,
                () -> service.search(1L, "ab", 20, (long) ProfileService.MAX_SEARCH_OFFSET + 1));
    }
}
