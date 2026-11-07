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

/** Profil tamamlama kapisi: yazma yollari tablosu, 403 PROFILE_INCOMPLETE govdesi, onbellek, acil kapatma. */
class ProfileIncompleteWriteFilterTest {

    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final I18n i18n = mock(I18n.class);
    private final ProfileCompletionGate gate = new ProfileCompletionGate(jdbc);
    private final ProfileIncompleteWriteFilter on = new ProfileIncompleteWriteFilter(gate, i18n, true);
    private final ProfileIncompleteWriteFilter off = new ProfileIncompleteWriteFilter(gate, i18n, false);

    @BeforeEach
    void setUp() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        when(i18n.msg(eq("error.PROFILE_INCOMPLETE"), any(Locale.class))).thenReturn("Profilinizi tamamlayin");
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @SuppressWarnings("unchecked")
    private void incomplete(boolean value) {
        when(jdbc.query(anyString(), any(RowMapper.class), anyLong())).thenReturn(List.of(value));
    }

    private MockHttpServletResponse run(ProfileIncompleteWriteFilter f, String method, String uri) throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest(method, uri);
        MockHttpServletResponse res = new MockHttpServletResponse();
        f.doFilter(req, res, new MockFilterChain());
        res.setCharacterEncoding("UTF-8");
        return res;
    }

    @Test
    void incompleteProfileIsBlockedOnEveryInteractionWrite() throws Exception {
        incomplete(true);
        for (String[] c : new String[][] {
                {"POST", "/api/posts"}, {"POST", "/api/posts/3/like"}, {"POST", "/api/users/4/follow"},
                {"POST", "/api/conversations"}, {"POST", "/api/conversations/3/messages"},
                {"POST", "/api/communities"}, {"POST", "/api/events"}, {"POST", "/api/events/3/rsvp"},
                {"POST", "/api/polls/3/vote"}, {"POST", "/api/communities/3/join"}, {"POST", "/api/feedback"},
                {"PUT", "/api/users/me/privacy"}, {"PUT", "/api/users/me/username"}, {"PATCH", "/api/users/me"},
                {"POST", "/api/users/me/contacts"}, {"POST", "/api/reports"}, {"POST", "/api/notifications/read"},
                {"DELETE", "/api/posts/3"}, {"POST", "/api/forum/topics"}}) {
            MockHttpServletResponse res = run(on, c[0], c[1]);
            assertThat(res.getStatus()).as(c[0] + " " + c[1]).isEqualTo(403);
            assertThat(res.getContentAsString()).contains("\"code\":\"PROFILE_INCOMPLETE\"")
                    .contains("\"message\":\"Profilinizi tamamlayin\"");
        }
    }

    @Test
    void onboardingAvatarDeleteAccountAuthDevicesAndReadsStayOpen() throws Exception {
        incomplete(true);
        for (String[] c : new String[][] {
                {"PUT", "/api/users/me/onboarding"}, {"POST", "/api/users/me/avatar"}, {"DELETE", "/api/users/me/avatar"},
                {"DELETE", "/api/users/me"}, {"POST", "/api/auth/logout"}, {"POST", "/api/auth/logout-all"},
                {"POST", "/api/auth/oauth/link"}, {"DELETE", "/api/auth/oauth/link/google"}, {"POST", "/api/auth/refresh"},
                {"POST", "/api/devices"}, {"POST", "/api/legal/accept"}, {"POST", "/api/analytics/events"},
                {"POST", "/api/app/crash-reports"}, {"POST", "/api/support/tickets"},
                {"GET", "/api/posts"}, {"GET", "/api/users/me"}, {"GET", "/api/users/username-available"},
                {"HEAD", "/api/news"}, {"OPTIONS", "/api/posts"}, {"GET", "/api/catalog/academic"}}) {
            MockHttpServletResponse res = run(on, c[0], c[1]);
            assertThat(res.getStatus()).as(c[0] + " " + c[1]).isEqualTo(200);
        }
    }

    @Test
    void wrongMethodOnExemptEndpointsIsStillBlocked() {
        assertThat(ProfileIncompleteWriteFilter.blockedForIncomplete("POST", "/api/users/me/onboarding")).isTrue();
        assertThat(ProfileIncompleteWriteFilter.blockedForIncomplete("PATCH", "/api/users/me/avatar")).isTrue();
        assertThat(ProfileIncompleteWriteFilter.blockedForIncomplete("POST", "/api/users/me")).isTrue();
        assertThat(ProfileIncompleteWriteFilter.blockedForIncomplete("PUT", "/api/users/me/onboarding")).isFalse();
        // /api disi (ws, files, actuator) ve prefix hilesi
        assertThat(ProfileIncompleteWriteFilter.blockedForIncomplete("POST", "/files/x")).isFalse();
        assertThat(ProfileIncompleteWriteFilter.blockedForIncomplete("POST", "/api/authority/x")).isTrue();
        assertThat(ProfileIncompleteWriteFilter.blockedForIncomplete("POST", "/api/appx")).isTrue();
    }

    @Test
    void completedProfileIsNeverBlockedAndTheResultIsCached() throws Exception {
        incomplete(false);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
        assertThat(run(on, "POST", "/api/conversations").getStatus()).isEqualTo(200);
        verify(jdbc, times(1)).query(anyString(), any(RowMapper.class), anyLong()); // tamamlandi sonucu bellekte
    }

    @Test
    void incompleteResultIsNotCachedSoTheGateOpensTheMomentOnboardingFinishes() throws Exception {
        incomplete(true);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(403);
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(403);
        incomplete(false); // onboarding bitti
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);
    }

    @Test
    void killSwitchDisablesTheGate() throws Exception {
        incomplete(true);
        assertThat(run(off, "POST", "/api/posts").getStatus()).isEqualTo(200);
    }

    @Test
    void anonymousRequestsAndQueryFailuresPassThrough() throws Exception {
        SecurityContextHolder.clearContext();
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200);

        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(8L, null, List.of()));
        when(jdbc.query(anyString(), any(RowMapper.class), anyLong())).thenThrow(new IllegalStateException("db"));
        assertThat(run(on, "POST", "/api/posts").getStatus()).isEqualTo(200); // kullaniciyi kilitleme
    }
}
