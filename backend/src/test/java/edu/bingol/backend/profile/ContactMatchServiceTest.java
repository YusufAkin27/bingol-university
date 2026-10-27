package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.ContactMatchDtos.MatchResponse;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ContactMatchServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final PublicProfileMapper mapper = mock(PublicProfileMapper.class);
    private final ContactMatchService service = new ContactMatchService(users, blocks, mapper);

    private static String h(String email) {
        return Hashing.sha256(email);
    }

    private static User user(long id, String email) {
        User u = new User();
        u.setId(id);
        u.setEmail(email);
        u.setEmailSha256(h(email));
        return u;
    }

    @SuppressWarnings("unchecked")
    private void mapperEchoesWithAvatar(String avatar) {
        when(mapper.mapAll(any(), any())).thenAnswer(inv -> ((List<User>) inv.getArgument(1)).stream()
                .map(u -> new PublicProfile(u.getId(), "Ad" + u.getId(), "Fak", "Bol", null, null, avatar, null))
                .toList());
    }

    @Test
    void matchesAndMapsProfileFields() {
        mapperEchoesWithAvatar("/files/avatars/a.jpg");
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(users.findContactMatches(any(), any())).thenReturn(List.of(user(12, "ali@bingol.edu.tr")));

        MatchResponse r = service.match(1L, List.of(h("ali@bingol.edu.tr")));

        assertEquals(1, r.matches().size());
        var m = r.matches().get(0);
        assertEquals(h("ali@bingol.edu.tr"), m.hash());
        assertEquals(12L, m.userId());
        assertEquals("Ad12", m.displayName());
        assertEquals("/files/avatars/a.jpg", m.avatarUrl());
        assertEquals("Fak", m.faculty());
    }

    @Test
    void privacyHiddenAvatarStaysNull() {
        mapperEchoesWithAvatar(null);
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(users.findContactMatches(any(), any())).thenReturn(List.of(user(12, "ali@bingol.edu.tr")));

        assertNull(service.match(1L, List.of(h("ali@bingol.edu.tr"))).matches().get(0).avatarUrl());
    }

    @Test
    void excludesSelfAndBlockedInBothDirections() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(9L));
        when(users.findContactMatches(any(), any())).thenReturn(List.of());

        service.match(1L, List.of(h("a@bingol.edu.tr")));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Collection<Long>> ex = ArgumentCaptor.forClass(Collection.class);
        verify(users).findContactMatches(any(), ex.capture());
        assertTrue(ex.getValue().containsAll(Set.of(1L, 9L)));
    }

    @Test
    void duplicatesAndCaseAndGarbageAreCollapsed() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(users.findContactMatches(any(), any())).thenReturn(List.of());
        String a = h("a@bingol.edu.tr");

        service.match(1L, List.of(a, a, a.toUpperCase(), "zzz", ""));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Collection<String>> hs = ArgumentCaptor.forClass(Collection.class);
        verify(users).findContactMatches(hs.capture(), any());
        assertEquals(List.of(a), new ArrayList<>(hs.getValue()));
    }

    @Test
    void emptyInputSkipsQuery() {
        assertTrue(service.match(1L, List.of()).matches().isEmpty());
        verify(users, never()).findContactMatches(any(), any());
    }

    @Test
    void moreThan500HashesIsRejected() {
        List<String> many = new ArrayList<>();
        for (int i = 0; i < 501; i++) {
            many.add(h("u" + i + "@bingol.edu.tr"));
        }
        ApiException e = assertThrows(ApiException.class, () -> service.match(1L, many));
        assertEquals("CONTACTS_TOO_MANY", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void exactly500IsAccepted() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(users.findContactMatches(any(), any())).thenReturn(List.of());
        List<String> many = new ArrayList<>();
        for (int i = 0; i < 500; i++) {
            many.add(h("u" + i + "@bingol.edu.tr"));
        }
        assertTrue(service.match(1L, many).matches().isEmpty());
    }
}
