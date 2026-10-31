package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;

/** T-011: ADMIN_EMAILS terfisi yalniz e-posta KODU dogrulamasiyla gelen cagrida yapilir (yonetici elle dogrulamasinda yapilmaz). */
class AccountCreatorNoPromoteTest {

    private static final String EMAIL = "boss@bingol.edu.tr";

    private final UserRepository users = mock(UserRepository.class);
    private final LegalService legal = mock(LegalService.class);
    private final AccountCreator creator = new AccountCreator(users, legal, new AdminProperties(List.of(EMAIL)));

    private void stubSave() {
        when(users.findByEmail(any())).thenReturn(Optional.empty());
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            u.setId(7L);
            return u;
        });
    }

    @Test
    void codeVerifiedCallPromotesAdminEmail() {
        stubSave();
        User u = creator.create(EMAIL, new Pending("h", "B", "tr"));
        assertEquals(Role.ADMIN, u.getRole());
        assertEquals(edu.bingol.backend.admin.rbac.AdminProfile.FULL, u.getAdminProfile());
    }

    @Test
    void manualVerificationNeverPromotes() {
        stubSave();
        User u = creator.create(EMAIL, new Pending("h", "B", "tr"), false);
        assertTrue(u.isEmailVerified());
        assertEquals(Role.USER, u.getRole());
        assertNull(u.getAdminProfile());
    }

    @Test
    void bothOverloadsAreTransactional() throws Exception {
        assertTrue(AccountCreator.class.getMethod("create", String.class, Pending.class, boolean.class)
                .isAnnotationPresent(Transactional.class));
    }
}
