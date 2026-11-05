package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.dto.ProfileDtos.ProfileView;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** Kota asiminda ertelenmis (dogrulanmamis) hesap baskalarina gorunmez; sahibi kendi profilini gorur. */
class UnverifiedProfileHiddenTest {

    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final PublicProfileMapper mapper = mock(PublicProfileMapper.class);
    private final ProfileService service = new ProfileService(users, blocks, null, null, null, null, mapper, null,
            null, null, null, null, null);

    private static User deferred(long id) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("U" + id);
        u.setEmail("u" + id + "@bingol.edu.tr");
        u.setEmailVerified(false);
        u.setVerificationDeferred(true);
        return u;
    }

    @Test
    void otherUsersGet404ForAnUnverifiedProfile() {
        when(users.findById(2L)).thenReturn(Optional.of(deferred(2L)));

        ApiException e = assertThrows(ApiException.class, () -> service.publicProfile(1L, 2L));

        assertEquals("USER_NOT_FOUND", e.code());
    }

    @Test
    void profileViewCarriesTheVerificationFlags() {
        User u = deferred(2L);
        u.setCreatedAt(Instant.parse("2026-11-05T10:00:00Z"));

        ProfileView v = ProfileView.of(u);

        assertEquals(false, v.emailVerified());
        assertEquals(true, v.verificationDeferred());
        u.setEmailVerified(true);
        u.setVerificationDeferred(false);
        ProfileView ok = ProfileView.of(u);
        assertEquals(true, ok.emailVerified());
        assertEquals(false, ok.verificationDeferred());
    }
}
