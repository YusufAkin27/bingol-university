package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
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

class AccountCreatorTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final UserRepository users = mock(UserRepository.class);
    private final LegalService legal = mock(LegalService.class);
    private final AccountCreator creator = new AccountCreator(users, legal, new AdminProperties(List.of(EMAIL)));

    @Test
    void createsVerifiedAdminAccountAndRecordsConsent() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            u.setId(5L);
            return u;
        });

        User u = creator.create(EMAIL, new Pending("h", "Ali", "tr"));

        assertTrue(u.isEmailVerified());
        assertEquals(Role.ADMIN, u.getRole());
        verify(legal).recordSignupConsent(5L);
    }

    @Test
    void writesAcademicFieldsFromPendingRegistration() {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            u.setId(6L);
            return u;
        });

        User u = creator.create(EMAIL, new Pending("h", "Ali", "tr", "Hukuk Fakültesi", "Hukuk", "PREP"));

        assertEquals("Hukuk Fakültesi", u.getFaculty());
        assertEquals("Hukuk", u.getDepartment());
        assertEquals("PREP", u.getGrade());
    }

    @Test
    void consentFailurePropagatesSoTransactionRollsBack() throws Exception {
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        when(users.saveAndFlush(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            u.setId(5L);
            return u;
        });
        doThrow(new IllegalStateException("db")).when(legal).recordSignupConsent(5L);

        assertThrows(IllegalStateException.class, () -> creator.create(EMAIL, new Pending("h", "Ali", "tr")));
        // Tek transaction: metot @Transactional olmali
        assertTrue(AccountCreator.class.getMethod("create", String.class, Pending.class)
                .isAnnotationPresent(Transactional.class));
    }
}
