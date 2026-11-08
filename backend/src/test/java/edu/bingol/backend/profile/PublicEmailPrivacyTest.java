package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.dto.ProfileDtos.UserSearchResult;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Collection;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** Guvenlik denetimi: showEmail=false iken baska kullanicinin e-postasi ne profilde ne aramada sizar. */
class PublicEmailPrivacyTest {

    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final AvatarVisibility visibility = mock(AvatarVisibility.class);
    private final PublicProfileMapper mapper = new PublicProfileMapper(visibility);
    private final ProfileService service = new ProfileService(users, blocks, null, null, null, null, mapper, null,
            null, null, null, null, null);

    private static User user(long id, boolean showEmail) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("Kisi " + id);
        u.setEmail("gizli" + id + "@example.com");
        u.setEmailVerified(true);
        u.setShowEmail(showEmail);
        return u;
    }

    @SuppressWarnings("unchecked")
    private void everythingVisible() {
        when(visibility.visibleOwners(any(), any(), any(Collection.class))).thenAnswer(inv -> {
            Map<Field, Set<Long>> m = new EnumMap<>(Field.class);
            Collection<Field> fields = inv.getArgument(2);
            Collection<Long> owners = inv.getArgument(1);
            for (Field f : fields) {
                m.put(f, Set.copyOf(owners));
            }
            return m;
        });
        when(blocks.hiddenFrom(any())).thenReturn(Set.of());
        when(blocks.isBlocked(any(), any())).thenReturn(false);
    }

    @Test
    void otherUsersEmailIsNullWhenShowEmailFalse() {
        everythingVisible();
        when(users.findById(2L)).thenReturn(Optional.of(user(2L, false)));

        PublicProfile p = service.publicProfile(1L, 2L);

        assertNull(p.email());
    }

    @Test
    void otherUsersEmailShownOnlyWhenOwnerAllowed() {
        everythingVisible();
        when(users.findById(3L)).thenReturn(Optional.of(user(3L, true)));

        assertEquals("gizli3@example.com", service.publicProfile(1L, 3L).email());
    }

    @Test
    void ownProfileAlwaysShowsOwnEmail() {
        everythingVisible();
        when(users.findById(2L)).thenReturn(Optional.of(user(2L, false)));

        assertNotNull(service.publicProfile(2L, 2L).email());
    }

    @Test
    void searchResultsNeverLeakHiddenEmails() {
        everythingVisible();
        when(users.searchByNameFolded(any(), any(), any(), any(), any(), any(), anyInt(), anyInt()))
                .thenReturn(List.of(user(2L, false), user(3L, true), user(4L, false)));

        UserSearchResult r = service.search(1L, "kisi", 20, null);

        assertEquals(3, r.items().size());
        for (PublicProfile p : r.items()) {
            if (p.id() == 3L) {
                assertNotNull(p.email());
            } else {
                assertNull(p.email(), "showEmail=false kullanicinin e-postasi aramada sizdi: " + p.id());
            }
        }
    }
}
