package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.ContactMatchDtos.MatchResponse;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ContactMatchServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final PublicProfileMapper mapper = mock(PublicProfileMapper.class);
    private final ProfilePrivacyRepository privacy = mock(ProfilePrivacyRepository.class);
    private final ContactMatchQuota quota = mock(ContactMatchQuota.class);
    private final ContactMatchService service = new ContactMatchService(users, blocks, mapper, privacy, quota);

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

    private static ProfilePrivacy discoverable(long userId, boolean on) {
        ProfilePrivacy p = ProfilePrivacy.defaults(userId);
        p.setContactsDiscoverable(on);
        return p;
    }

    /** Gorunen kullanici (1) bulunabilir; verilen hedefler de bulunabilir olarak isaretlenir. */
    private void viewerOptedIn(long... optedInTargets) {
        when(privacy.findById(1L)).thenReturn(Optional.of(discoverable(1L, true)));
        List<ProfilePrivacy> rows = new ArrayList<>();
        for (long t : optedInTargets) {
            rows.add(discoverable(t, true));
        }
        when(privacy.findByUserIdIn(any())).thenReturn(rows);
    }

    @SuppressWarnings("unchecked")
    private void mapperEchoesWithAvatar(String avatar) {
        when(mapper.mapAll(any(), any())).thenAnswer(inv -> ((List<User>) inv.getArgument(1)).stream()
                .map(u -> new PublicProfile(u.getId(), "Ad" + u.getId(), "Fak", "Bol", null, null, avatar, null))
                .toList());
    }

    @BeforeEach
    void defaults() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
    }

    @Test
    void matchesAndMapsProfileFields() {
        viewerOptedIn(12);
        mapperEchoesWithAvatar("/files/avatars/a.jpg");
        when(users.findContactMatches(any(), any())).thenReturn(List.of(user(12, "ali@bingol.edu.tr")));

        MatchResponse r = service.match(1L, List.of(h("ali@bingol.edu.tr")));

        assertEquals(1, r.matches().size());
        var m = r.matches().get(0);
        assertEquals(h("ali@bingol.edu.tr"), m.hash());
        assertEquals(12L, m.userId());
        assertEquals("Ad12", m.displayName());
        assertEquals("/files/avatars/a.jpg", m.avatarUrl());
        assertEquals("Fak", m.faculty());
        verify(quota).consume(1L, 1);
    }

    @Test
    void privacyHiddenAvatarStaysNull() {
        viewerOptedIn(12);
        mapperEchoesWithAvatar(null);
        when(users.findContactMatches(any(), any())).thenReturn(List.of(user(12, "ali@bingol.edu.tr")));

        assertNull(service.match(1L, List.of(h("ali@bingol.edu.tr"))).matches().get(0).avatarUrl());
    }

    /** T-061: bulunabilir demeyen kullanici eslesmede donmez (varsayilan KAPALI). */
    @Test
    void userWhoDidNotOptInIsNeverReturned() {
        viewerOptedIn(); // hicbir hedef acik onay vermedi
        when(users.findContactMatches(any(), any())).thenReturn(List.of(user(12, "ali@bingol.edu.tr")));

        MatchResponse r = service.match(1L, List.of(h("ali@bingol.edu.tr")));

        assertTrue(r.matches().isEmpty());
        verify(mapper, never()).mapAll(any(), any());
    }

    @Test
    void privacyRowMissingMeansNotDiscoverable() {
        viewerOptedIn();
        when(privacy.findByUserIdIn(any())).thenReturn(List.of()); // satir yok
        when(users.findContactMatches(any(), any())).thenReturn(List.of(user(12, "ali@bingol.edu.tr")));

        assertTrue(service.match(1L, List.of(h("ali@bingol.edu.tr"))).matches().isEmpty());
    }

    /** T-061: karsilikli; kendisi bulunabilir olmayan kullanici eslestirme yapamaz. */
    @Test
    void viewerWhoIsNotDiscoverableCannotMatch() {
        when(privacy.findById(1L)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class, () -> service.match(1L, List.of(h("a@bingol.edu.tr"))));

        assertEquals("CONTACTS_DISCOVERABLE_REQUIRED", e.code());
        assertEquals(403, e.status().value());
        verify(users, never()).findContactMatches(any(), any());
        verify(quota, never()).consume(any(), anyInt());
    }

    /** T-061: okul numarasi adresleri (numara@bingol.edu.tr) rehber eslesmesinden cikarilir. */
    @Test
    void schoolNumberAddressesAreExcluded() {
        viewerOptedIn(12, 13);
        mapperEchoesWithAvatar(null);
        when(users.findContactMatches(any(), any())).thenReturn(List.of(
                user(12, "226051015@bingol.edu.tr"), user(13, "ali.veli@bingol.edu.tr")));

        MatchResponse r = service.match(1L, List.of(h("226051015@bingol.edu.tr"), h("ali.veli@bingol.edu.tr")));

        assertEquals(1, r.matches().size());
        assertEquals(13L, r.matches().get(0).userId());
    }

    @Test
    void isSchoolNumberOnlyForPureDigitLocalPart() {
        assertTrue(ContactMatchService.isSchoolNumber("226051015@bingol.edu.tr"));
        assertFalse(ContactMatchService.isSchoolNumber("a226051015@bingol.edu.tr"));
        assertFalse(ContactMatchService.isSchoolNumber("ali.veli@ogr.bingol.edu.tr"));
        assertFalse(ContactMatchService.isSchoolNumber(null));
    }

    /** T-061: gunluk aday tavani asilirsa 429 ve sorgu calismaz. */
    @Test
    void dailyCandidateCapStopsTheQuery() {
        viewerOptedIn();
        doThrow(new RateLimitedException(3600)).when(quota).consume(eq(1L), anyInt());

        assertThrows(RateLimitedException.class, () -> service.match(1L, List.of(h("a@bingol.edu.tr"))));
        verify(users, never()).findContactMatches(any(), any());
    }

    @Test
    void excludesSelfAndBlockedInBothDirections() {
        viewerOptedIn();
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
        viewerOptedIn();
        when(users.findContactMatches(any(), any())).thenReturn(List.of());
        String a = h("a@bingol.edu.tr");

        service.match(1L, List.of(a, a, a.toUpperCase(), "zzz", ""));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Collection<String>> hs = ArgumentCaptor.forClass(Collection.class);
        verify(users).findContactMatches(hs.capture(), any());
        assertEquals(List.of(a), new ArrayList<>(hs.getValue()));
        verify(quota).consume(1L, 1); // tekil aday sayisi sayilir
    }

    @Test
    void emptyInputSkipsQuery() {
        viewerOptedIn();
        assertTrue(service.match(1L, List.of()).matches().isEmpty());
        verify(users, never()).findContactMatches(any(), any());
    }

    @Test
    void moreThan500HashesIsRejected() {
        viewerOptedIn();
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
        viewerOptedIn();
        when(users.findContactMatches(any(), any())).thenReturn(List.of());
        List<String> many = new ArrayList<>();
        for (int i = 0; i < 500; i++) {
            many.add(h("u" + i + "@bingol.edu.tr"));
        }
        assertTrue(service.match(1L, many).matches().isEmpty());
    }

    @Test
    void setDiscoverableCreatesDefaultsRowAndSaves() {
        when(privacy.findById(5L)).thenReturn(Optional.empty());

        service.setDiscoverable(5L, true);

        ArgumentCaptor<ProfilePrivacy> saved = ArgumentCaptor.forClass(ProfilePrivacy.class);
        verify(privacy).save(saved.capture());
        assertEquals(5L, saved.getValue().getUserId());
        assertTrue(saved.getValue().isContactsDiscoverable());
    }

    @Test
    void discoverableDefaultsToFalse() {
        when(privacy.findById(5L)).thenReturn(Optional.empty());
        assertFalse(service.isDiscoverable(5L));
        assertFalse(ProfilePrivacy.defaults(5L).isContactsDiscoverable());
    }
}
