package edu.bingol.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** Kota asiminda ertelenmis dogrulama: yalniz okuma modu (yazma yollari tablosu, 403 govdesi, onbellek). */
class UnverifiedWriteFilterTest {

    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final I18n i18n = mock(I18n.class);
    private final UnverifiedWriteFilter on = new UnverifiedWriteFilter(jdbc, i18n, true);
    private final UnverifiedWriteFilter off = new UnverifiedWriteFilter(jdbc, i18n, false);

    @BeforeEach
    void setUp() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        when(i18n.msg(eq("error.EMAIL_VERIFICATION_REQUIRED"), any(Locale.class))).thenReturn("Dogrulayin");
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @SuppressWarnings("unchecked")
    private void restricted(boolean value) {
        when(jdbc.query(anyString(), any(RowMapper.class), anyLong())).thenReturn(List.of(value));
    }

    private MockHttpServletResponse run(UnverifiedWriteFilter f, String method, String uri) throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest(method, uri);
        MockHttpServletResponse res = new MockHttpServletResponse();
        f.doFilter(req, res, new MockFilterChain());
        res.setCharacterEncoding("UTF-8");
        return res;
    }

    @Test
    void restrictedUserIsBlockedOnWriteEndpoints() throws Exception {
        restricted(true);
        for (String[] c : new String[][] {
                {"POST", "/api/posts"}, {"POST", "/api/posts/3/like"}, {"POST", "/api/users/4/follow"},
                {"POST", "/api/conversations"}, {"POST", "/api/conversations/3/messages"},
                {"POST", "/api/communities"}, {"POST", "/api/events"}, {"POST", "/api/events/3/rsvp"},
                {"POST", "/api/polls/3/vote"}, {"POST", "/api/communities/3/join"}, {"POST", "/api/feedback"},
                {"POST", "/api/auth/2fa/enable/request"}, {"PUT", "/api/users/me/privacy"},
                {"POST", "/api/users/me/contacts"}, {"PATCH", "/api/admin/users/3"}}) {
            MockHttpServletResponse res = run(on, c[0], c[1]);
            assertThat(res.getStatus()).as(c[0] + " " + c[1]).isEqualTo(403);
            assertThat(res.getContentAsString()).contains("\"code\":\"EMAIL_VERIFICATION_REQUIRED\"")
                    .contains("\"message\":\"Dogrulayin\"");
        }
    }

    @Test
    void allowedWritesAndReadsPassForRestrictedUser() throws Exception {
        restricted(true);
        for (String[] c : new String[][] {
                {"GET", "/api/posts"}, {"GET", "/api/users/me"}, {"HEAD", "/api/news"},
                {"PATCH", "/api/users/me"}, {"DELETE", "/api/users/me"},
                {"POST", "/api/users/me/avatar"}, {"DELETE", "/api/users/me/avatar"},
                {"POST", "/api/auth/verification/resend"}, {"POST", "/api/auth/verification/verify"},
                {"POST", "/api/auth/logout"}, {"POST", "/api/auth/logout-all"}, {"POST", "/api/auth/refresh"},
                {"POST", "/api/legal/accept"}, {"POST", "/api/devices"}, {"POST", "/api/analytics/events"},
                {"POST", "/api/support/tickets"}, {"POST", "/api/reports"}, {"POST", "/api/app/crash-reports"},
                {"POST", "/api/notifications/read-all"}, {"POST", "/api/public/support/tickets"}}) {
            assertThat(run(on, c[0], c[1]).getStatus()).as(c[0] + " " + c[1]).isEqualTo(200);
        }
        // segment siniri: "/api/reportsx" muaf degildir; /users/me altindaki diger yazmalar kisitli
        assertThat(run(on, "POST", "/api/reportsx").getStatus()).isEqualTo(403);
        assertThat(run(on, "PUT", "/api/users/me").getStatus()).isEqualTo(403);
        assertThat(run(on, "PUT", "/api/users/me/avatar").getStatus()).isEqualTo(403);
    }

    @Test
    void verifiedUserPassesAndTheResultIsCached() throws Exception {
        restricted(false);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
        assertThat(run(on, "POST", "/api/conversations").getStatus()).isEqualTo(200);
        verify(jdbc, times(1)).query(anyString(), any(RowMapper.class), anyLong());
    }

    @Test
    void restrictedResultIsNotCachedSoVerificationLiftsItImmediately() throws Exception {
        restricted(true);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(403);
        restricted(false);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
    }

    @Test
    void anonymousAndDisabledFilterDoNothing() throws Exception {
        restricted(true);
        SecurityContextHolder.clearContext();
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        assertThat(run(off, "POST", "/api/posts").getStatus()).isEqualTo(200);
    }

    @Test
    void queryFailureNeverLocksTheUserOut() throws Exception {
        when(jdbc.query(anyString(), any(RowMapper.class), anyLong())).thenThrow(new RuntimeException("db down"));
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
    }
}
