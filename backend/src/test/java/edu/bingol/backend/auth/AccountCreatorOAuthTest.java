package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.oauth.OAuthProperties;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

/** OAuth hesabi: dogrulanmis, parolasiz, profil TAMAMLANMAMIS, sozlesme onayi yok; parola kayitlari varsayilan tamamlanmis. */
class AccountCreatorOAuthTest {

    private final UserRepository users = mock(UserRepository.class);
    private final LegalService legal = mock(LegalService.class);
    private final ProfilePrivacyRepository privacy = mock(ProfilePrivacyRepository.class);
    private final AccountCreator creator = new AccountCreator(users, legal, new AdminProperties(List.of("yonetici@gmail.com")));

    @BeforeEach
    void wire() {
        ReflectionTestUtils.setField(creator, "privacy", privacy);
        ReflectionTestUtils.setField(creator, "defaultPrivateAccount", false);
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            if (u.getId() == null) {
                u.setId(9L);
            }
            return u;
        });
    }

    @Test
    void oauthAccountIsVerifiedPasswordlessIncompleteAndPublic() {
        User u = creator.createFromOAuth("kisi@gmail.com", "Ayşe Yılmaz", "Ayşe", "Yılmaz", "en");

        assertTrue(u.isEmailVerified());
        assertFalse(u.isVerificationDeferred());
        assertFalse(u.hasPassword());
        assertTrue(u.getPasswordHash().startsWith(User.NO_PASSWORD_PREFIX));
        assertNull(u.getProfileCompletedAt(), "onboarding bitene kadar sunucu kapisi yazmayi keser");
        assertEquals("en", u.getLanguage());
        assertEquals("Ayşe", u.getFirstName());
        assertEquals(Role.USER, u.getRole());
        verify(legal, never()).recordSignupConsent(any()); // sozlesme onayi onboarding'de
        ArgumentCaptor<ProfilePrivacy> p = ArgumentCaptor.forClass(ProfilePrivacy.class);
        verify(privacy, never()).save(any()); // varsayilan herkese acik: gizlilik satiri yazilmaz
    }

    @Test
    void oauthAccountWithAdminEmailIsNotPromoted() {
        User u = creator.createFromOAuth("yonetici@gmail.com", "Y", null, null, "tr");
        assertEquals(Role.USER, u.getRole());
        assertNull(u.getAdminProfile());
    }

    @Test
    void passwordSignupsAreCompleteByDefaultSoTheExistingMobileFlowIsNotLocked() {
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.empty());

        User u = creator.create("ali@bingol.edu.tr", new Pending("h", "Ali", "tr"));

        assertNotNull(u.getProfileCompletedAt());
        verify(legal).recordSignupConsent(9L);
    }

    @Test
    void passwordSignupsGoThroughOnboardingWhenTheFlagIsOn() {
        ReflectionTestUtils.setField(creator, "oauthProps", new OAuthProperties(true, List.of(), List.of(), true, true));
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.empty());

        User u = creator.create("ali@bingol.edu.tr", new Pending("h", "Ali", "tr"));

        assertNull(u.getProfileCompletedAt());
    }

    @Test
    void existingRowKeepsItsCompletionEvenWhenTheFlagIsOn() {
        ReflectionTestUtils.setField(creator, "oauthProps", new OAuthProperties(true, List.of(), List.of(), true, true));
        User existing = new User();
        existing.setId(4L);
        when(users.findByEmail("ali@bingol.edu.tr")).thenReturn(Optional.of(existing));

        User u = creator.create("ali@bingol.edu.tr", new Pending("h", "Ali", "tr"));

        assertNotNull(u.getProfileCompletedAt(), "var olan satir (ertelenmis dogrulama vb.) kilitlenmez");
    }
}
