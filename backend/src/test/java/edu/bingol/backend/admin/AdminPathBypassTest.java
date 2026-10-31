package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.rbac.AdminPermissionInterceptor;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.admin.rbac.AdminProfileResolver;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.I18n;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * T-010: yuzde-kodlu yol segmentiyle (/%63onversations, /%65xport.csv, /%72ole) izin, gerekce/hiz ve denetim kararlarinin
 * atlatilamadigini kanitlar. Spring MVC segmenti cozerek eslestirir; yonetici interceptor/filtreleri de AdminPaths ile
 * AYNI cozulmus yolu kullanmalidir.
 */
class AdminPathBypassTest {

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpServletRequest req(String method, String rawUri) {
        MockHttpServletRequest r = new MockHttpServletRequest(method, rawUri);
        r.setRequestURI(rawUri); // ham (kodlu) yol: getRequestURI() cozmez
        return r;
    }

    private static AdminPermissionInterceptor permission(AdminProfile p) {
        AdminProfileResolver resolver = mock(AdminProfileResolver.class);
        when(resolver.resolve(any(), any())).thenReturn(new AdminProfileResolver.Resolved(p, false));
        return new AdminPermissionInterceptor(resolver);
    }

    private static void assertDenied(AdminProfile p, String method, String uri) {
        ApiException e = assertThrows(ApiException.class,
                () -> permission(p).preHandle(req(method, uri), new MockHttpServletResponse(), null),
                p + " " + method + " " + uri + " REDDEDILMELI");
        assertEquals("ADMIN_PERMISSION_DENIED", e.code());
        assertEquals(403, e.status().value());
    }

    // --- cozumleyici ---

    @Test
    void decodeResolvesEncodedLettersLikeSpringMvc() {
        assertEquals("/api/admin/users/1/conversations", AdminPaths.decode("/api/admin/users/1/%63onversations"));
        assertEquals("/api/admin/users/export.csv", AdminPaths.decode("/api/admin/users/%65xport.csv"));
        assertEquals("/api/admin/users/1/role", AdminPaths.decode("/api/admin/users/1/%72ole"));
        assertEquals("/api/admin/pending-registrations/a@bingol.edu.tr/verify",
                AdminPaths.decode("/api/admin/pending-registrations/a%40bingol.edu.tr/verify"));
        assertEquals("/api/admin/users", AdminPaths.decode("/api/admin/users?x=%63"));
        assertEquals("/api/admin/users/3", AdminPaths.decode("/api/admin/users/3;jsessionid=1"));
        // cozulemeyen/bozuk kodlama oldugu gibi kalir (hicbir ozel kurala eslesmez => en siki varsayilan)
        assertEquals("/api/admin/%zz", AdminPaths.decode("/api/admin/%zz"));
        // kodlu '/' segmenti bolemez
        assertEquals("/api/admin/users/1_role", AdminPaths.decode("/api/admin/users/1%2Frole"));
    }

    @Test
    void contextPathIsStripped() {
        MockHttpServletRequest r = req("GET", "/app/api/admin/users/%65xport.csv");
        r.setContextPath("/app");
        assertEquals("/api/admin/users/export.csv", AdminPaths.of(r));
    }

    @Test
    void onlyAtSignEncodingIsSafe() {
        assertFalse(AdminPaths.hasUnsafeEncoding("/api/admin/users/1/conversations"));
        assertFalse(AdminPaths.hasUnsafeEncoding("/api/admin/pending-registrations/a%40bingol.edu.tr/verify"));
        assertTrue(AdminPaths.hasUnsafeEncoding("/api/admin/users/1/%63onversations"));
        assertTrue(AdminPaths.hasUnsafeEncoding("/api/admin/pending-registrations/a%2Bb%40bingol.edu.tr/verify"));
        assertTrue(AdminPaths.hasUnsafeEncoding("/api/admin/users/%"));
        assertTrue(AdminPaths.hasUnsafeEncoding("/api/admin/users/%4"));
        assertTrue(AdminPaths.isAdmin("/api/admin"));
        assertTrue(AdminPaths.isAdmin("/api/admin/x"));
        assertFalse(AdminPaths.isAdmin("/api/adminx/x"));
    }

    // --- izin interceptor'u ---

    @Test
    void viewerCannotReadChatOrCsvWithEncodedSegments() {
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/users/2/conversations"); // referans: kodsuz yol
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/users/2/%63onversations");
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/users/2/%63onversations/5/messages");
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/users/%65xport.csv");
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/users/2/%64evices");
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/users/2/%73essions");
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/pending-registrations/%65xport.csv");
        assertDenied(AdminProfile.VIEWER, "GET", "/api/admin/%75sers/2/conversations");
    }

    @Test
    void moderatorCannotChangeRoleOrForceSyncWithEncodedSegments() {
        assertDenied(AdminProfile.MODERATOR, "PATCH", "/api/admin/users/2/%72ole");
        assertDenied(AdminProfile.MODERATOR, "POST", "/api/admin/sources/%73ync");
        assertDenied(AdminProfile.MODERATOR, "POST", "/api/admin/users/2/%65xport");
        assertDenied(AdminProfile.MODERATOR, "DELETE", "/api/admin/users/%32");
        assertDenied(AdminProfile.SUPPORT, "GET", "/api/admin/users/2/%70ush-devices");
    }

    @Test
    void headIsEvaluatedWithGetRules() {
        assertDenied(AdminProfile.VIEWER, "HEAD", "/api/admin/users/2/conversations");
        assertDenied(AdminProfile.VIEWER, "HEAD", "/api/admin/users/export.csv");
        assertDenied(AdminProfile.VIEWER, "HEAD", "/api/admin/users/2/%63onversations");
        assertDenied(AdminProfile.VIEWER, "HEAD", "/api/admin/users/2/sessions");
    }

    @Test
    void legitimatePermissionStillPasses() {
        assertTrue(permission(AdminProfile.MODERATOR).preHandle(req("GET", "/api/admin/users/2/conversations"),
                new MockHttpServletResponse(), null));
        assertTrue(permission(AdminProfile.FULL).preHandle(req("GET", "/api/admin/users/export.csv"),
                new MockHttpServletResponse(), null));
    }

    // --- gerekce / hiz interceptor'u ---

    @Test
    void reasonAndRateRulesApplyToEncodedSegments() {
        RateLimiter limiter = mock(RateLimiter.class);
        var g = new AdminGuardInterceptor(limiter, true, 60, 20);
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))));

        ApiException e = assertThrows(ApiException.class,
                () -> g.preHandle(req("PATCH", "/api/admin/users/2/%72ole"), new MockHttpServletResponse(), null));
        assertEquals("REASON_REQUIRED", e.code());
        verify(limiter).check(org.mockito.ArgumentMatchers.eq("admd:7"), anyInt(), any()); // yikici sinir da isledi

        ApiException d = assertThrows(ApiException.class,
                () -> g.preHandle(req("DELETE", "/api/admin/users/%32"), new MockHttpServletResponse(), null));
        assertEquals("REASON_REQUIRED", d.code());
    }

    // --- denetim ---

    @Test
    void encodedCsvExportAndPersonalReadsAreAudited() {
        AuditRepository repo = mock(AuditRepository.class);
        AuditInterceptor audit = new AuditInterceptor(new AuditRecorder(repo, new ClientIp("127.0.0.0/8")));
        SecurityContextHolder.clearContext();

        audit.afterCompletion(req("GET", "/api/admin/users/%65xport.csv"), new MockHttpServletResponse(), null, null);
        verify(repo).insert(any(), any(), org.mockito.ArgumentMatchers.eq("GET"), any(), anyInt(), any(),
                any(AuditRepository.Details.class));

        audit.afterCompletion(req("GET", "/api/admin/users/%32/%73essions"), new MockHttpServletResponse(), null, null);
        verify(repo, org.mockito.Mockito.times(2)).insert(any(), any(), any(), any(), anyInt(), any(),
                any(AuditRepository.Details.class));
    }

    // --- ek savunma: 400 filtre ---

    private static AdminPathGuardFilter filter() {
        I18n i18n = mock(I18n.class);
        when(i18n.msg(org.mockito.ArgumentMatchers.eq("error.ADMIN_PATH_INVALID"), any(java.util.Locale.class)))
                .thenReturn("gecersiz yol");
        return new AdminPathGuardFilter(i18n);
    }

    private static int run(String method, String rawUri) throws Exception {
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();
        filter().doFilter(req(method, rawUri), res, chain);
        return chain.getRequest() == null ? res.getStatus() : -1; // -1: zincire devam etti
    }

    @Test
    void filterRejectsEncodedAdminPathsButAllowsEmailAtSign() throws Exception {
        assertEquals(400, run("GET", "/api/admin/users/1/%63onversations"));
        assertEquals(400, run("PATCH", "/api/admin/users/1/%72ole"));
        assertEquals(400, run("GET", "/api/%61dmin/users"));
        assertEquals(400, run("GET", "/api/admin/users/export%2Ecsv"));
        assertEquals(-1, run("POST", "/api/admin/pending-registrations/a%40bingol.edu.tr/verify"));
        assertEquals(-1, run("GET", "/api/admin/users/1/conversations"));
        assertEquals(-1, run("GET", "/api/news/%63")); // yonetici disi yollar etkilenmez
    }

    @Test
    void filterResponseIsJsonErrorEnvelope() throws Exception {
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter().doFilter(req("GET", "/api/admin/users/1/%63onversations"), res, new MockFilterChain());
        assertEquals(400, res.getStatus());
        assertTrue(res.getContentAsString().contains("\"code\":\"ADMIN_PATH_INVALID\""), res.getContentAsString());
        assertNull(res.getHeader("WWW-Authenticate"));
    }

    @Test
    void controlCharactersInReasonAreFlagged() {
        assertTrue(AdminReasonFilter.hasControlChars("a\r\nSet-Cookie: x"));
        assertTrue(AdminReasonFilter.hasControlChars("a\tb"));
        assertFalse(AdminReasonFilter.hasControlChars("normal gerekce"));
        assertFalse(AdminReasonFilter.hasControlChars(null));
        // guvenlik duvari: bayrakli istek 400 REASON_INVALID
        MockHttpServletRequest r = req("POST", "/api/admin/faq");
        AuditContext.of(r).reasonInvalid(true);
        ApiException e = assertThrows(ApiException.class, () -> new AdminGuardInterceptor(mock(RateLimiter.class), true,
                60, 20).preHandle(r, new MockHttpServletResponse(), null));
        assertEquals("REASON_INVALID", e.code());
    }
}
