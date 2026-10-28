package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalDtos.PendingConsent;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/** Yeniden onay zorlamasi: yalniz yazma uclari, muaf yollar, kapali ayar ve onbellek. */
class LegalReacceptFilterTest {

    private final LegalService legal = mock(LegalService.class);
    private final I18n i18n = mock(I18n.class);
    private final LegalReacceptFilter on = new LegalReacceptFilter(legal, i18n, true);
    private final LegalReacceptFilter off = new LegalReacceptFilter(legal, i18n, false);

    @BeforeEach
    void setUp() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
        when(i18n.msg(eq("error.LEGAL_REACCEPT_REQUIRED"), any(Locale.class))).thenReturn("Onay gerekli");
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private MockHttpServletResponse run(LegalReacceptFilter f, String method, String uri) throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest(method, uri);
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();
        f.doFilter(req, res, chain);
        res.setCharacterEncoding("UTF-8");
        return res;
    }

    private void pendingTerms() {
        when(legal.pending(7L, Lang.DEFAULT)).thenReturn(List.of(new PendingConsent(LegalType.PRIVACY, 5, "Gizlilik")));
    }

    @Test
    void pendingUserIsBlockedOnWriteEndpoints() throws Exception {
        pendingTerms();
        MockHttpServletResponse res = run(on, "POST", "/api/communities/3/posts");
        assertThat(res.getStatus()).isEqualTo(403);
        assertThat(res.getContentAsString()).contains("\"code\":\"LEGAL_REACCEPT_REQUIRED\"")
                .contains("\"type\":\"PRIVACY\",\"version\":5");
    }

    @Test
    void readsAndExemptPathsPass() throws Exception {
        pendingTerms();
        for (String[] c : new String[][] {
                {"GET", "/api/news"}, {"POST", "/api/auth/logout"}, {"POST", "/api/legal/consents"},
                {"POST", "/api/legal/accept"}, {"DELETE", "/api/users/me"}, {"GET", "/api/users/me/export"},
                {"POST", "/api/support/tickets"}, {"POST", "/api/public/support/tickets"},
                {"POST", "/api/analytics/events"}, {"POST", "/api/devices/state"}, {"PUT", "/api/admin/settings/x"}}) {
            assertThat(run(on, c[0], c[1]).getStatus()).as(c[0] + " " + c[1]).isEqualTo(200);
        }
        // "/api/legalx" muaf degildir (segment siniri)
        assertThat(run(on, "POST", "/api/legalx").getStatus()).isEqualTo(403);
    }

    @Test
    void disabledSettingNeverBlocks() throws Exception {
        pendingTerms();
        assertThat(run(off, "POST", "/api/communities/3/posts").getStatus()).isEqualTo(200);
    }

    @Test
    void userWithoutPendingPassesAndResultIsCached() throws Exception {
        when(legal.pending(7L, Lang.DEFAULT)).thenReturn(List.of());
        assertThat(run(on, "POST", "/api/messages").getStatus()).isEqualTo(200);
        assertThat(run(on, "POST", "/api/messages").getStatus()).isEqualTo(200);
        verify(legal, times(1)).pending(7L, Lang.DEFAULT);
    }

    @Test
    void anonymousRequestsAreLeftToSecurity() throws Exception {
        SecurityContextHolder.clearContext();
        assertThat(run(on, "POST", "/api/messages").getStatus()).isEqualTo(200);
    }

    @Test
    void lookupFailureDoesNotLockTheUserOut() throws Exception {
        when(legal.pending(7L, Lang.DEFAULT)).thenThrow(new IllegalStateException("db"));
        assertThat(run(on, "POST", "/api/messages").getStatus()).isEqualTo(200);
    }
}
