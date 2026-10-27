package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.PendingRegistrationStore.Entry;
import edu.bingol.backend.auth.token.PendingRegistrationStore.EntryPage;
import edu.bingol.backend.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

class AdminPendingRegistrationControllerTest {

    private final PendingRegistrationStore store = mock(PendingRegistrationStore.class);
    private final AdminAccountVerificationService verification = mock(AdminAccountVerificationService.class);
    private final AdminPendingRegistrationController c = new AdminPendingRegistrationController(store, verification);

    @Test
    void listClampsSizeAndPassesCursor() {
        EntryPage page = new EntryPage(List.of(new Entry("226051015@bingol.edu.tr", "Ali", null, null, null,
                1L, 3600, 2)), "x@bingol.edu.tr");
        when(store.list("a", 100, "ali")).thenReturn(page);

        assertEquals(page, c.list("a", 5000, "ali"));
        verify(store).list("a", 100, "ali");
    }

    @Test
    void cancelAcceptsStudentNumber() {
        when(store.remove("226051015@bingol.edu.tr")).thenReturn(true);

        c.cancel("226051015");

        verify(store).remove("226051015@bingol.edu.tr");
    }

    @Test
    void cancelUnknownIs404() {
        ApiException e = assertThrows(ApiException.class, () -> c.cancel("yok@bingol.edu.tr"));
        assertEquals("NOT_FOUND", e.code());
    }

    @Test
    void verifyReturns201Body() {
        edu.bingol.backend.user.User u = new edu.bingol.backend.user.User();
        u.setId(9L);
        u.setEmail("226051015@bingol.edu.tr");
        u.setDisplayName("Ali");
        when(verification.verifyPending("226051015", null)).thenReturn(u);

        var r = c.verify("226051015", new org.springframework.security.authentication.TestingAuthenticationToken("admin", "x"));

        assertEquals(9L, r.id());
        assertEquals("226051015@bingol.edu.tr", r.email());
    }

    @Test
    void resendDelegates() {
        c.resend("226051015");
        verify(verification).resendPending("226051015");
    }
}
