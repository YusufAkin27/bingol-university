package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

class AuditRecorderTest {

    private final AuditRepository repo = mock(AuditRepository.class);
    private final AuditRecorder recorder = new AuditRecorder(repo, new edu.bingol.backend.common.ClientIp("127.0.0.0/8"));

    @Test
    void onlyWritesAndCsvExportAreAudited() {
        assertTrue(AuditRecorder.shouldAudit("POST", "/api/admin/legal/terms"));
        assertTrue(AuditRecorder.shouldAudit("PATCH", "/api/admin/users/3/role"));
        assertTrue(AuditRecorder.shouldAudit("DELETE", "/api/admin/users/3"));
        assertTrue(AuditRecorder.shouldAudit("POST", "/api/admin/pending-registrations/226051015@bingol.edu.tr/verify"));
        assertTrue(AuditRecorder.shouldAudit("POST", "/api/admin/users/3/verify-email"));
        assertTrue(AuditRecorder.shouldAudit("PUT", "/api/admin/settings/website"));
        assertTrue(AuditRecorder.shouldAudit("GET", "/api/admin/users/export.csv"));
        assertFalse(AuditRecorder.shouldAudit("GET", "/api/admin/users"));
        assertFalse(AuditRecorder.shouldAudit("GET", "/api/admin/audit"));
        assertFalse(AuditRecorder.shouldAudit("OPTIONS", "/api/admin/users"));
        assertFalse(AuditRecorder.shouldAudit("HEAD", "/api/admin/users"));
    }

    @Test
    void jwtAdminIsRecordedByIdWithoutBodyOrQuery() {
        MockHttpServletRequest req = new MockHttpServletRequest("PATCH", "/api/admin/users/3/role");
        req.setQueryString("secret=1");
        req.setContent("{\"role\":\"ADMIN\"}".getBytes());
        req.setRemoteAddr("10.1.2.3");
        var auth = new UsernamePasswordAuthenticationToken(5L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));

        recorder.record(req, auth, 204);

        verify(repo).insert(5L, null, "PATCH", "/api/admin/users/3/role", 204, "10.1.2.3");
    }

    @Test
    void basicAuthAdminRecordedByUsername() {
        MockHttpServletRequest req = new MockHttpServletRequest("DELETE", "/api/admin/faq/1");
        var auth = new UsernamePasswordAuthenticationToken("admin", null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));

        recorder.record(req, auth, 204);

        verify(repo).insert(isNull(), org.mockito.ArgumentMatchers.eq("admin"), org.mockito.ArgumentMatchers.eq("DELETE"),
                org.mockito.ArgumentMatchers.eq("/api/admin/faq/1"), anyInt(), any());
    }

    @Test
    void databaseFailureNeverBreaksTheRequest() {
        doThrow(new RuntimeException("db down")).when(repo).insert(any(), any(), any(), any(), anyInt(), any());
        recorder.record(new MockHttpServletRequest("POST", "/api/admin/x"), null, 200);
        // exception firlatmadan donmesi yeterli
    }

    @Test
    void interceptorSkipsGetRequests() {
        AuditInterceptor interceptor = new AuditInterceptor(recorder);
        SecurityContextHolder.clearContext();

        interceptor.afterCompletion(new MockHttpServletRequest("GET", "/api/admin/users"), new MockHttpServletResponse(), null, null);

        verify(repo, never()).insert(any(), any(), any(), any(), anyInt(), any());
    }

    @Test
    void interceptorRecordsUncaughtErrorAs500() {
        AuditInterceptor interceptor = new AuditInterceptor(recorder);
        MockHttpServletResponse res = new MockHttpServletResponse(); // durum 200 gorunur
        SecurityContextHolder.clearContext();

        interceptor.afterCompletion(new MockHttpServletRequest("POST", "/api/admin/sync"), res, null, new RuntimeException("x"));

        verify(repo).insert(isNull(), isNull(), org.mockito.ArgumentMatchers.eq("POST"),
                org.mockito.ArgumentMatchers.eq("/api/admin/sync"), org.mockito.ArgumentMatchers.eq(500), any());
        assertEquals(200, res.getStatus());
    }
}
