package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.AuditRepository;
import edu.bingol.backend.common.ClientIp;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** "Bu ben degilim": tum oturumlar kapanir, denetim yazilir, denetim hatasi islemi bozmaz, yanit genel. */
class NotMeServiceTest {

    private final AuthService auth = mock(AuthService.class);
    private final AuditRepository audit = mock(AuditRepository.class);
    private final ClientIp clientIp = mock(ClientIp.class);
    private final HttpServletRequest http = mock(HttpServletRequest.class);
    private final NotMeService service = new NotMeService(auth, audit, clientIp);

    @Test
    void closesAllSessionsAndWritesAuditRowWithoutPii() {
        when(clientIp.of(http)).thenReturn("9.9.9.9");
        service.notMe(5L, http);

        verify(auth).logoutAll(5L);
        ArgumentCaptor<AuditRepository.Details> d = ArgumentCaptor.forClass(AuditRepository.Details.class);
        verify(audit).insert(eq((Long) null), eq("user:5"), eq("POST"), eq("/api/security/not-me"), eq(200), eq("9.9.9.9"),
                d.capture());
        assertEquals("USER", d.getValue().targetType());
        assertEquals("5", d.getValue().targetId());
        assertTrue(d.getValue().summary().contains("oturum"));
    }

    @Test
    void auditFailureNeverUndoesTheSecurityAction() {
        doThrow(new IllegalStateException("db")).when(audit).insert(any(), any(), anyString(), anyString(), anyInt(),
                any(), any());
        service.notMe(5L, http); // istisna sizmaz
        verify(auth).logoutAll(5L);
    }
}
