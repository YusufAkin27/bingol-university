package edu.bingol.backend.support.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** T-021: herkese acik talebin userId'si null; kullanici uclari NPE/500 yerine 404 TICKET_NOT_FOUND dondurur. */
class TicketServiceOwnTicketTest {

    private final TicketRepository tickets = mock(TicketRepository.class);
    private final SupportMessageRepository messages = mock(SupportMessageRepository.class);
    private final TicketService svc = new TicketService(tickets, messages, mock(UserRepository.class),
            mock(NotificationService.class));

    private SupportTicket publicTicket(long id) {
        SupportTicket t = new SupportTicket();
        t.setId(id);
        t.setPublicTicket(true);
        t.setEmailVerified(true);
        t.setContactEmail("misafir@example.com");
        t.setSubject("s");
        t.setCategory(SupportTicket.Category.OTHER);
        when(tickets.findById(id)).thenReturn(Optional.of(t));
        return t;
    }

    private static void assertNotFound(ApiException e) {
        assertEquals(HttpStatus.NOT_FOUND, e.status());
        assertEquals("TICKET_NOT_FOUND", e.code());
    }

    @Test
    void publicTicketIdYields404OnEveryUserEndpoint() {
        publicTicket(9L);
        assertNotFound(assertThrows(ApiException.class, () -> svc.detail(5L, 9L)));
        assertNotFound(assertThrows(ApiException.class, () -> svc.userReply(5L, 9L, "merhaba")));
        assertNotFound(assertThrows(ApiException.class, () -> svc.userClose(5L, 9L)));
    }

    @Test
    void someoneElsesTicketIsAlso404() {
        SupportTicket t = publicTicket(10L);
        t.setPublicTicket(false);
        t.setUserId(77L);
        assertNotFound(assertThrows(ApiException.class, () -> svc.detail(5L, 10L)));
    }
}
