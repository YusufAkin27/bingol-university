package edu.bingol.backend.auth.realemail;

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

/** Gercek e-posta kapisi: yazma yollari tablosu, 403 REAL_EMAIL_REQUIRED govdesi, onbellek, acil kapatma. */
class RealEmailRequiredWriteFilterTest {

    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final I18n i18n = mock(I18n.class);
    private final RealEmailRequiredWriteFilter on = new RealEmailRequiredWriteFilter(new RealEmailGate(jdbc, true), i18n);
    private final RealEmailRequiredWriteFilter off = new RealEmailRequiredWriteFilter(new RealEmailGate(jdbc, false), i18n);

    @BeforeEach
    void setUp() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        when(i18n.msg(eq("error.REAL_EMAIL_REQUIRED"), any(Locale.class))).thenReturn("Gercek e-posta ekleyin");
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @SuppressWarnings("unchecked")
    private void required(boolean value) {
        when(jdbc.query(anyString(), any(RowMapper.class), anyLong())).thenReturn(List.of(value));
    }

    private MockHttpServletResponse run(RealEmailRequiredWriteFilter f, String method, String uri) throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest(method, uri);
        MockHttpServletResponse res = new MockHttpServletResponse();
        f.doFilter(req, res, new MockFilterChain());
        res.setCharacterEncoding("UTF-8");
        return res;
    }

    @Test
    void gatedAccountIsBlockedOnInteractionWrites() throws Exception {
        required(true);
        for (String[] c : new String[][] {
                {"POST", "/api/posts"}, {"POST", "/api/posts/3/like"}, {"POST", "/api/users/4/follow"},
                {"POST", "/api/conversations"}, {"POST", "/api/communities"}, {"POST", "/api/events/3/rsvp"},
                {"PUT", "/api/users/me/privacy"}, {"PUT", "/api/users/me/username"}, {"POST", "/api/forum/topics"},
                {"POST", "/api/users/me/contacts"}, {"DELETE", "/api/posts/3"}}) {
            MockHttpServletResponse res = run(on, c[0], c[1]);
            assertThat(res.getStatus()).as(c[0] + " " + c[1]).isEqualTo(403);
            assertThat(res.getContentAsString()).contains("\"code\":\"REAL_EMAIL_REQUIRED\"")
                    .contains("\"message\":\"Gercek e-posta ekleyin\"");
        }
    }

    @Test
    void emailFlowProfileOnboardingAuthLegalAndReadsStayOpen() throws Exception {
        required(true);
        for (String[] c : new String[][] {
                {"POST", "/api/users/me/email/start"}, {"POST", "/api/users/me/email/verify"},
                {"PUT", "/api/users/me/onboarding"}, {"PATCH", "/api/users/me"}, {"DELETE", "/api/users/me"},
                {"POST", "/api/users/me/avatar"}, {"DELETE", "/api/users/me/avatar"},
                {"POST", "/api/auth/logout"}, {"POST", "/api/auth/logout-all"}, {"POST", "/api/auth/refresh"},
                {"POST", "/api/auth/oauth/link"}, {"POST", "/api/legal/accept"}, {"POST", "/api/devices"},
                {"POST", "/api/analytics/events"}, {"POST", "/api/support/tickets"}, {"POST", "/api/reports"},
                {"POST", "/api/app/crash-reports"},
                {"GET", "/api/posts"}, {"GET", "/api/users/me"}, {"GET", "/api/conversations"},
                {"HEAD", "/api/news"}, {"OPTIONS", "/api/posts"}}) {
            MockHttpServletResponse res = run(on, c[0], c[1]);
            assertThat(res.getStatus()).as(c[0] + " " + c[1]).isEqualTo(200);
        }
    }

    @Test
    void wrongMethodOnExemptEndpointsAndPrefixTricksAreStillBlocked() {
        assertThat(RealEmailRequiredWriteFilter.blockedForRealEmail("POST", "/api/users/me/onboarding")).isTrue();
        assertThat(RealEmailRequiredWriteFilter.blockedForRealEmail("PUT", "/api/users/me")).isTrue();
        assertThat(RealEmailRequiredWriteFilter.blockedForRealEmail("PATCH", "/api/users/me/avatar")).isTrue();
        assertThat(RealEmailRequiredWriteFilter.blockedForRealEmail("POST", "/api/users/me/emailx")).isTrue();
        assertThat(RealEmailRequiredWriteFilter.blockedForRealEmail("POST", "/api/users/me/email")).isFalse();
        assertThat(RealEmailRequiredWriteFilter.blockedForRealEmail("POST", "/api/authority/x")).isTrue();
        assertThat(RealEmailRequiredWriteFilter.blockedForRealEmail("POST", "/files/x")).isFalse();
    }

    @Test
    void clearAccountIsNeverBlockedAndTheResultIsCachedButGatedIsNot() throws Exception {
        required(false);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
        verify(jdbc, times(1)).query(anyString(), any(RowMapper.class), anyLong());

        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(8L, null, List.of()));
        required(true);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(403);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(403);
        required(false); // gercek e-posta dogrulandi: kapi aninda acilir
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
    }

    @Test
    void killSwitchAnonymousAndQueryFailuresPassThrough() throws Exception {
        required(true);
        assertThat(run(off, "POST", "/api/posts").getStatus()).isEqualTo(200);

        SecurityContextHolder.clearContext();
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);

        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(9L, null, List.of()));
        when(jdbc.query(anyString(), any(RowMapper.class), anyLong())).thenThrow(new IllegalStateException("db"));
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200); // kullaniciyi kilitleme
    }
}
