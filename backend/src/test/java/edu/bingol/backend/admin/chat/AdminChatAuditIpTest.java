package edu.bingol.backend.admin.chat;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * FIX-P09 (A08#7): sohbet izleme erisim kaydina (message_access_audit.ip, degistirilemez KVKK kaniti) yazilan IP,
 * nginx arkasinda proxy adresi degil guvenilir proxy zincirinden cozulen gercek istemci olmali.
 */
class AdminChatAuditIpTest {

    private static final String PROXY = "172.18.0.5";
    private static final String CLIENT = "85.105.20.7";

    private final ClientIp clientIp = new ClientIp("127.0.0.0/8,172.16.0.0/12");
    private final RateLimiter limiter = mock(RateLimiter.class);

    @BeforeEach
    void admin() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(900L, null, java.util.List.of()));
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private static MockHttpServletRequest viaProxy() {
        MockHttpServletRequest r = new MockHttpServletRequest();
        r.setRemoteAddr(PROXY);
        r.addHeader("X-Forwarded-For", CLIENT);
        return r;
    }

    @Test
    void feedControllerPassesTheRealClientIpToTheAuditedService() {
        AdminChatFeedService svc = mock(AdminChatFeedService.class);
        AdminChatFeedController c = new AdminChatFeedController(svc, limiter, clientIp);

        c.media(null, 30, null, null, null, 5L, null, null, null, "desc", viaProxy());
        verify(svc).media(eq(900L), any(), anyInt(), any(), any(), any(), any(), any(), any(), any(), anyString(), eq(CLIENT));

        c.messages(null, 30, 5L, null, null, null, null, null, null, null, viaProxy());
        verify(svc).messages(eq(900L), any(), anyInt(), any(), any(), any(), any(), any(), any(), any(), any(), eq(CLIENT));

        c.stats(viaProxy());
        verify(svc).stats(900L, CLIENT);
    }

    @Test
    void viewerControllerPassesTheRealClientIp() {
        AdminChatViewerService svc = mock(AdminChatViewerService.class);
        AdminChatViewerController c = new AdminChatViewerController(svc, limiter, clientIp);

        c.conversations(5L, null, 20, viaProxy());
        verify(svc).conversations(eq(900L), eq(5L), any(), anyInt(), eq(CLIENT));

        c.messages(5L, 10L, null, 50, viaProxy());
        verify(svc).messages(eq(900L), eq(5L), eq(10L), any(), anyInt(), eq(CLIENT));
    }

    @Test
    void reportContextControllerPassesTheRealClientIp() {
        AdminReportContextService svc = mock(AdminReportContextService.class);
        AdminReportContextController c = new AdminReportContextController(svc, limiter, clientIp);

        c.detail(77L, viaProxy());
        verify(svc).detail(900L, 77L, CLIENT);
    }

    @Test
    void forgedForwardedForFromAnUntrustedPeerIsIgnored() {
        AdminChatFeedService svc = mock(AdminChatFeedService.class);
        AdminChatFeedController c = new AdminChatFeedController(svc, limiter, clientIp);
        MockHttpServletRequest direct = new MockHttpServletRequest();
        direct.setRemoteAddr("203.0.113.9"); // guvenilir proxy degil
        direct.addHeader("X-Forwarded-For", "1.2.3.4");

        c.stats(direct);

        verify(svc).stats(anyLong(), eq("203.0.113.9"));
    }
}
