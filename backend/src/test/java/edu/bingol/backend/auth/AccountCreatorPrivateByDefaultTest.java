package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;

/** Yeni hesap varsayilan HERKESE ACIK acilir (2026-11-07); ayar acilirsa gizli (profile_privacy.private_account), mevcut hesaba dokunulmaz. */
class AccountCreatorPrivateByDefaultTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final UserRepository users = mock(UserRepository.class);
    private final LegalService legal = mock(LegalService.class);
    private final ProfilePrivacyRepository privacy = mock(ProfilePrivacyRepository.class);
    private final AccountCreator creator = new AccountCreator(users, legal, new AdminProperties(List.of()));

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
    void newAccountStartsPrivateWhenSettingOn() {
        ReflectionTestUtils.setField(creator, "defaultPrivateAccount", true);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        creator.create(EMAIL, new Pending("h", "Ali", "tr"));

        ArgumentCaptor<ProfilePrivacy> saved = ArgumentCaptor.forClass(ProfilePrivacy.class);
        verify(privacy).save(saved.capture());
        assertEquals(9L, saved.getValue().getUserId());
        assertTrue(saved.getValue().isPrivateAccount());
    }

    @Test
    void newAccountIsPublicByDefault() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());

        creator.create(EMAIL, new Pending("h", "Ali", "tr"));

        verify(privacy, never()).save(any());
    }

    @Test
    void existingAccountPrivacyIsNotTouched() {
        User existing = new User();
        existing.setId(4L);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(existing));

        creator.create(EMAIL, new Pending("h", "Ali", "tr"));

        verify(privacy, never()).save(any());
    }
}
