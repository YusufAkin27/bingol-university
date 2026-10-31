package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.method.HandlerMethod;

/** Yonetici yazma guvenligi: politika tablosu, hiz siniri, sebep zorunlulugu, sebep ayiklama, hedef cikarimi. */
class AdminGuardTest {

    private final RateLimiter limiter = mock(RateLimiter.class);

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private void login(long id) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(id, null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))));
    }

    // --- politika ---

    @Test
    void criticalOperationsNeedReason() {
        assertEquals(5, AdminGuardPolicy.reasonMin("PATCH", "/api/admin/users/3/role"));
        assertEquals(5, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/users/3"));
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/legal/terms"));
        assertEquals(5, AdminGuardPolicy.reasonMin("PUT", "/api/admin/settings/maintenance_mode"));
        assertEquals(5, AdminGuardPolicy.reasonMin("PUT", "/api/admin/settings/min_version_android"));
        assertEquals(5, AdminGuardPolicy.reasonMin("PUT", "/api/admin/settings/store_url_ios"));
        assertEquals(5, AdminGuardPolicy.reasonMin("PUT", "/api/admin/settings/support_email"));
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/access-bans/bulk"));
    }

    /** T-011/T-013: gerekce ve yikici sinir kapsami (onceden gerekcesiz kalan uclar). */
    @Test
    void previouslyUnguardedEndpointsNowNeedReason() {
        for (String[] r : new String[][] {
                {"PUT", "/api/admin/settings/banner_text"}, {"PUT", "/api/admin/settings/contact_email"},
                {"POST", "/api/admin/users/3/verify-email"}, {"POST", "/api/admin/users/3/send-reset"},
                {"POST", "/api/admin/users/3/revoke-sessions"}, {"POST", "/api/admin/users/3/suspend"},
                {"POST", "/api/admin/users/3/block-access"},
                {"POST", "/api/admin/pending-registrations/a@bingol.edu.tr/verify"},
                {"POST", "/api/admin/posts/3/hide"}, {"POST", "/api/admin/posts/3/unhide"},
                {"POST", "/api/admin/community-posts/3/hide"}, {"DELETE", "/api/admin/posts/3"},
                {"PATCH", "/api/admin/news/3"}, {"POST", "/api/admin/access-bans"},
                {"POST", "/api/admin/push/campaigns"}, {"POST", "/api/admin/push/campaigns/3/cancel"},
                {"POST", "/api/admin/mail/campaigns"}, {"POST", "/api/admin/mail/campaigns/3/schedule"},
                {"POST", "/api/admin/mail/campaigns/3/cancel"}, {"POST", "/api/admin/crypto/rewrap"},
                {"POST", "/api/admin/moderation/appeals/3/decide"}}) {
            assertEquals(5, AdminGuardPolicy.reasonMin(r[0], r[1]), r[0] + " " + r[1]);
            assertTrue(AdminGuardPolicy.destructive(r[0], r[1]), r[0] + " " + r[1] + " yikici sayilmali");
        }
        // okuma, test gonderimi ve kitle onizlemesi gerekce istemez
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/posts/3"));
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/push/campaigns/test"));
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/mail/campaigns/audience/preview"));
        assertEquals(0, AdminGuardPolicy.reasonMin("PATCH", "/api/admin/posts/3"));
    }

    @Test
    void ordinaryOperationsDoNotNeedReason() {
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/users/3"));
        assertEquals(0, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/faq/1"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/legal/terms/versions"));
    }

    @Test
    void destructiveSetIncludesAccountOpsAndCritical() {
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/users/3"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/users/3/send-reset"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/users/3/revoke-sessions"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/users/3/verify-email"));
        assertTrue(AdminGuardPolicy.destructive("PATCH", "/api/admin/users/3/role"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/pending-registrations/a@bingol.edu.tr"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/moderation/blocklist"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/moderation/blocklist/abc"));
        assertFalse(AdminGuardPolicy.destructive("DELETE", "/api/admin/faq/1"));
        assertFalse(AdminGuardPolicy.destructive("GET", "/api/admin/users/3"));
    }

    // --- hiz siniri ---

    @Test
    void writesAreRateLimitedPerAdmin() {
        login(7L);
        var g = new AdminGuardInterceptor(limiter, false, 60, 20);

        g.preHandle(new MockHttpServletRequest("POST", "/api/admin/faq"), new MockHttpServletResponse(), null);

        verify(limiter).check("admw:7", 60, Duration.ofMinutes(1));
        verify(limiter, never()).check(eq("admd:7"), anyInt(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void destructiveWritesGetHourlyLimitToo() {
        login(7L);
        var g = new AdminGuardInterceptor(limiter, false, 60, 20);

        g.preHandle(new MockHttpServletRequest("DELETE", "/api/admin/users/3"), new MockHttpServletResponse(), null);

        verify(limiter).check("admw:7", 60, Duration.ofMinutes(1));
        verify(limiter).check("admd:7", 20, Duration.ofHours(1));
    }

    @Test
    void readsAreNotLimitedHere() {
        login(7L);
        var g = new AdminGuardInterceptor(limiter, true, 60, 20);

        g.preHandle(new MockHttpServletRequest("GET", "/api/admin/users"), new MockHttpServletResponse(), null);

        verify(limiter, never()).check(anyString(), anyInt(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void basicAuthAdminSharesOneBucket() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken("admin", null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))));
        var g = new AdminGuardInterceptor(limiter, false, 60, 20);

        g.preHandle(new MockHttpServletRequest("POST", "/api/admin/faq"), new MockHttpServletResponse(), null);

        verify(limiter).check("admw:basic", 60, Duration.ofMinutes(1));
    }

    @Test
    void limitExceededPropagates429() {
        login(7L);
        doThrow(new RateLimitedException(42)).when(limiter).check(eq("admw:7"), anyInt(), org.mockito.ArgumentMatchers.any());
        var g = new AdminGuardInterceptor(limiter, false, 60, 20);

        RateLimitedException e = assertThrows(RateLimitedException.class,
                () -> g.preHandle(new MockHttpServletRequest("POST", "/api/admin/faq"), new MockHttpServletResponse(), null));

        assertEquals(429, e.status().value());
        assertEquals(42, e.retryAfterSeconds());
    }

    // --- sebep zorunlulugu ---

    @Test
    void criticalWriteWithoutReasonIs400() {
        login(7L);
        var g = new AdminGuardInterceptor(limiter, true, 60, 20);
        MockHttpServletRequest req = new MockHttpServletRequest("PATCH", "/api/admin/users/3/role");

        ApiException e = assertThrows(ApiException.class, () -> g.preHandle(req, new MockHttpServletResponse(), null));

        assertEquals("REASON_REQUIRED", e.code());
        assertEquals(400, e.status().value());
        assertEquals("5", e.args()[0]);
    }

    @Test
    void shortReasonIsRejectedGoodReasonPasses() {
        login(7L);
        var g = new AdminGuardInterceptor(limiter, true, 60, 20);
        MockHttpServletRequest shortReq = new MockHttpServletRequest("DELETE", "/api/admin/users/3");
        AuditContext.of(shortReq).reason("abc");
        assertEquals("REASON_REQUIRED",
                assertThrows(ApiException.class, () -> g.preHandle(shortReq, new MockHttpServletResponse(), null)).code());

        MockHttpServletRequest ok = new MockHttpServletRequest("DELETE", "/api/admin/users/3");
        AuditContext.of(ok).reason("kullanici talebi uzerine");
        assertTrue(g.preHandle(ok, new MockHttpServletResponse(), null));
    }

    @Test
    void reasonNotEnforcedWhenDisabled() {
        login(7L);
        var g = new AdminGuardInterceptor(limiter, false, 60, 20);
        assertTrue(g.preHandle(new MockHttpServletRequest("PATCH", "/api/admin/users/3/role"),
                new MockHttpServletResponse(), null));
    }

    @Test
    void annotatedHandlerNeedsReasonWithItsOwnMinimum() throws Exception {
        login(7L);
        var g = new AdminGuardInterceptor(limiter, true, 60, 20);
        var hm = new HandlerMethod(new Chatty(), Chatty.class.getMethod("open"));
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/admin/x");
        AuditContext.of(req).reason("kisa sebep"); // 10 karakter
        assertTrue(g.preHandle(req, new MockHttpServletResponse(), hm));

        MockHttpServletRequest tooShort = new MockHttpServletRequest("GET", "/api/admin/x");
        AuditContext.of(tooShort).reason("123456789");
        ApiException e = assertThrows(ApiException.class, () -> g.preHandle(tooShort, new MockHttpServletResponse(), hm));
        assertEquals("10", e.args()[0]);
    }

    static class Chatty {
        @AdminReasonRequired(min = AdminGuardPolicy.CHAT_MIN_REASON)
        public void open() {}
    }

    // --- sebep ayiklama (filtre) ---

    @Test
    void reasonFromHeaderIsUrlDecoded() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("PATCH", "/api/admin/users/3/role");
        req.addHeader(AdminReasonFilter.HEADER, "yetki%20d%C3%BCzeltme");

        new AdminReasonFilter().doFilter(req, new MockHttpServletResponse(), new org.springframework.mock.web.MockFilterChain());

        assertEquals("yetki düzeltme", AuditContext.of(req).reason());
    }

    @Test
    void reasonFromJsonBodyIsReadAndBodyStaysReadable() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("PATCH", "/api/admin/users/3/role");
        req.setContentType("application/json");
        byte[] body = "{\"role\":\"USER\",\"reason\":\"politika ihlali\"}".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        req.setContent(body);
        String[] seen = new String[1];

        new AdminReasonFilter().doFilter(req, new MockHttpServletResponse(), (r, s) -> {
            seen[0] = new String(r.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        });

        assertEquals("politika ihlali", AuditContext.of(req).reason());
        assertEquals(new String(body, java.nio.charset.StandardCharsets.UTF_8), seen[0]);
    }

    @Test
    void malformedBodyAndForeignShapesGiveNoReason() {
        assertNull(AdminReasonFilter.fromJson("{not json".getBytes()));
        assertNull(AdminReasonFilter.fromJson("[1,2]".getBytes()));
        assertNull(AdminReasonFilter.fromJson("{\"reason\":5}".getBytes()));
    }

    @Test
    void getReasonComesFromQueryParameter() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/admin/users/3/conversations");
        req.setParameter("reason", "sikayet incelemesi 123");

        new AdminReasonFilter().doFilter(req, new MockHttpServletResponse(), new org.springframework.mock.web.MockFilterChain());

        assertEquals("sikayet incelemesi 123", AuditContext.of(req).reason());
    }

    @Test
    void auditContextCleansControlCharsAndClips() {
        var d = new AuditContext.Data().reason("a\r\nb\tc").summary("x".repeat(900));
        assertEquals("a b c", d.reason());
        assertEquals(AuditContext.MAX_SUMMARY, d.summary().length());
        assertNull(new AuditContext.Data().reason("   ").reason());
    }

    // --- hedef cikarimi ---

    @Test
    void targetsAreInferredFromPath() {
        assertTarget("/api/admin/users/3/role", "USER", "3");
        assertTarget("/api/admin/users/3", "USER", "3");
        assertTarget("/api/admin/users/3/conversations/9/messages", "USER", "3");
        assertTarget("/api/admin/settings/maintenance_mode", "SETTING", "maintenance_mode");
        assertTarget("/api/admin/legal/terms", "LEGAL", "terms");
        assertTarget("/api/admin/news/12", "NEWS", "12");
        assertTarget("/api/admin/communities/5/approve", "COMMUNITY", "5");
        assertTarget("/api/admin/support/tickets/8/reply", "TICKET", "8");
        assertTarget("/api/admin/moderation/appeals/4/decide", "APPEAL", "4");
        assertTarget("/api/admin/access-bans/bulk", "ACCESS_BAN", null);
        assertTarget("/api/admin/pending-registrations/a@bingol.edu.tr/verify", "PENDING_REGISTRATION", "a@bingol.edu.tr");
        assertTarget("/api/admin/users/export.csv", "USER", null);
        assertTarget("/api/admin/audit/export.csv", "AUDIT", null);
    }

    private static void assertTarget(String path, String type, String id) {
        var t = AuditTargets.infer(path);
        assertEquals(type, t.type(), path);
        assertEquals(id, t.id(), path);
    }
}
