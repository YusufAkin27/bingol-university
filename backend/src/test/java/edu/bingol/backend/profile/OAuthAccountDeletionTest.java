package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.appinfo.AppInfoService;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.privacy.AvatarCleanups;
import edu.bingol.backend.profile.privacy.PublicProfileMapper;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.password.PasswordEncoder;

/** Hesap silme (KVKK): OAuth/onboarding kisisel alanlari temizlenir, kimlik satirlari AccountDataPurger ile silinir. */
class OAuthAccountDeletionTest {

    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder enc = mock(PasswordEncoder.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final AccountDataPurger purger = mock(AccountDataPurger.class);
    private final SessionService sessions = mock(SessionService.class);

    @SuppressWarnings("unchecked")
    private ProfileService service() {
        when(redis.opsForValue()).thenReturn(mock(ValueOperations.class));
        EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
        when(rsvps.findByUserId(any())).thenReturn(List.of());
        ProfileService s = new ProfileService(users, mock(BlockService.class), mock(MediaService.class), enc,
                mock(AppInfoService.class), mock(ActivityRepository.class), mock(PublicProfileMapper.class),
                mock(AvatarCleanups.class), rsvps, mock(UserEventRepository.class), redis, purger, null);
        s.setSessions(sessions);
        return s;
    }

    private User oauthUser() {
        User u = new User();
        u.setId(5L);
        u.setEmail("kisi@gmail.com");
        u.setRole(Role.USER);
        u.setPasswordHash(User.NO_PASSWORD_PREFIX + "x");
        u.setStatus(UserStatus.ACTIVE);
        u.setFirstName("Ayse");
        u.setLastName("Yilmaz");
        u.setUsername("ayse.y");
        u.setUniversityName("Bingol Universitesi");
        u.setBio("merhaba");
        when(users.findById(5L)).thenReturn(Optional.of(u));
        return u;
    }

    @Test
    void reauthenticatedDeletionAnonymizesOnboardingFieldsAndFreesTheUsername() {
        User u = oauthUser();

        service().deleteAccountReauthenticated(5L);

        assertEquals(UserStatus.DELETED, u.getStatus());
        assertNull(u.getFirstName());
        assertNull(u.getLastName());
        assertNull(u.getUsername(), "kullanici adi baskasinin alabilmesi icin bosalir");
        assertNull(u.getUsernameSetAt());
        assertNull(u.getUniversityName());
        assertNull(u.getBio());
        assertTrue(u.getPasswordHash().startsWith(ProfileService.UNUSABLE_PASSWORD_PREFIX));
        verify(purger).purge(5L, "kisi@gmail.com"); // auth_identity DELETES listesinde (asagidaki test)
        verify(redis.opsForValue()).set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 5L, "1");
    }

    @Test
    void passwordPathStillRejectsAPasswordlessAccountAndNullPassword() {
        oauthUser();
        when(enc.matches(any(), any())).thenReturn(false);
        for (String pw : new String[] {null, "herhangi"}) {
            var e = org.junit.jupiter.api.Assertions.assertThrows(edu.bingol.backend.common.ApiException.class,
                    () -> service().deleteAccount(5L, pw));
            assertEquals("WRONG_PASSWORD", e.code());
        }
    }

    @Test
    void authIdentityRowsAreDeletedByThePurger() {
        assertTrue(AccountDataPurger.DELETES.contains("DELETE FROM auth_identity WHERE user_id = ?"));
        assertTrue(AccountDataPurger.EMAIL_KEYED.containsKey("auth_identity.email"));
    }
}
